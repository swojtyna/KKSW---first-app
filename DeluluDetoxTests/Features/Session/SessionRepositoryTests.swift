import XCTest
import Combine
@testable import DeluluDetox

@MainActor
final class SessionRepositoryTests: XCTestCase {

    private var tempDir: URL!
    private var activeURL: URL!
    private var historyURL: URL!
    private var markerURL: URL!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        activeURL = tempDir.appendingPathComponent("active_session.json")
        historyURL = tempDir.appendingPathComponent("sessions.json")
        markerURL = tempDir.appendingPathComponent("session_finalize_marker.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        cancellables.removeAll()
        try await super.tearDown()
    }

    private func makeRepo() -> SessionRepositoryImpl {
        SessionRepositoryImpl(
            activeURLProvider: { [activeURL] in activeURL! },
            historyURLProvider: { [historyURL] in historyURL! },
            markerURLProvider: { [markerURL] in markerURL! },
            appVersion: "test"
        )
    }

    // MARK: - Fresh container

    func testInitOnFreshContainerReturnsNilActiveAndEmptyHistoryViaPublishers() async {
        let repo = makeRepo()
        // activeSessionPublisher is AnyPublisher<SessionRecord?, Never>.
        // currentActive is SessionRecord? — the first emission from a CurrentValueSubject.
        let currentActive = currentActiveSession(from: repo)
        XCTAssertNil(currentActive)
        XCTAssertEqual(currentHistory(from: repo).isEmpty, true)
    }

    // MARK: - Start

    func testStartSessionWritesBothFilesAtomicallyAndEmitsOnBothPublishers() async throws {
        let repo = makeRepo()
        let blocklistId = UUID()
        guard let duration = SessionDuration.preset(30) else { return XCTFail("preset 30 nil") }
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let record = try await repo.startSession(blocklistId: blocklistId, duration: duration, now: now)

        // File checks.
        XCTAssertTrue(FileManager.default.fileExists(atPath: activeURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: historyURL.path))

        let activeDecoded = try JSONDecoder().decode(SessionRecord.self, from: Data(contentsOf: activeURL))
        XCTAssertEqual(activeDecoded, record)
        XCTAssertTrue(activeDecoded.isActive)

        let historyDecoded = try JSONDecoder().decode([SessionRecord].self, from: Data(contentsOf: historyURL))
        XCTAssertEqual(historyDecoded.count, 1)
        XCTAssertEqual(historyDecoded.first, record)

        // Publisher checks.
        XCTAssertEqual(currentActiveSession(from: repo), record)
        XCTAssertEqual(currentHistory(from: repo), [record])

        // plannedEndAt math.
        XCTAssertEqual(record.plannedEndAt.timeIntervalSince1970 - now.timeIntervalSince1970, TimeInterval(30 * 60))
        XCTAssertEqual(record.plannedDurationSeconds, 30 * 60)
        XCTAssertEqual(record.blocklistId, blocklistId)
        XCTAssertEqual(record.appVersion, "test")
    }

    // MARK: - Finalize

    func testFinalizeActiveSessionUpdatesHistoryRecordAndDeletesActiveFile() async throws {
        let repo = makeRepo()
        guard let duration = SessionDuration.preset(30) else { return XCTFail() }
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let started = try await repo.startSession(blocklistId: UUID(), duration: duration, now: now)

        let end = Date(timeIntervalSince1970: 1_700_001_800)
        try await repo.finalizeActiveSession(outcome: .completed, actualEndAt: end)

        // active_session.json deleted.
        XCTAssertFalse(FileManager.default.fileExists(atPath: activeURL.path))

        // history updated on disk.
        let history = try JSONDecoder().decode([SessionRecord].self, from: Data(contentsOf: historyURL))
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.id, started.id)
        XCTAssertEqual(history.first?.actualEndAt, end)
        XCTAssertEqual(history.first?.outcome, .completed)
        XCTAssertFalse(history.first?.isActive ?? true)

        // Publishers.
        XCTAssertNil(currentActiveSession(from: repo))
        XCTAssertEqual(currentHistory(from: repo).count, 1)
    }

    func testFinalizeActiveSessionThrowsWhenNoneActive() async {
        let repo = makeRepo()
        do {
            try await repo.finalizeActiveSession(outcome: .completed, actualEndAt: Date())
            XCTFail("expected SessionStoreError.noActiveSession")
        } catch let error as SessionStoreError {
            if case .noActiveSession = error {} else { XCTFail("wrong case \(error)") }
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    // MARK: - Cross-instance persistence

    func testPersistenceAcrossRepoInstances() async throws {
        let repoA = makeRepo()
        guard let duration = SessionDuration.preset(15) else { return XCTFail() }
        let started = try await repoA.startSession(blocklistId: UUID(), duration: duration, now: Date())

        // New instance reading the same files.
        let repoB = makeRepo()
        let repoBActiveRecord: SessionRecord? = currentActiveSession(from: repoB)
        XCTAssertEqual(repoBActiveRecord?.id, started.id)
        XCTAssertEqual(currentHistory(from: repoB).count, 1)
    }

    // MARK: - Finalize marker

    func testConsumeFinalizeMarkerDeletesMarkerFileAfterReturn() async throws {
        let repo = makeRepo()
        let marker = SessionFinalizeMarker(
            sessionId: UUID(),
            finalizedAt: Date(),
            source: .damIntervalDidEnd
        )
        try JSONEncoder().encode(marker).write(to: markerURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerURL.path))

        let returned = try await repo.consumeFinalizeMarker()
        XCTAssertEqual(returned, marker)
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerURL.path))
    }

    func testConsumeFinalizeMarkerReturnsNilWhenAbsent() async throws {
        let repo = makeRepo()
        let result = try await repo.consumeFinalizeMarker()
        XCTAssertNil(result)
    }

    // MARK: - Disk re-read

    func testLoadActiveSessionFromDiskReturnsCurrentRecordAfterStart() async throws {
        let repo = makeRepo()
        guard let duration = SessionDuration.preset(15) else { return XCTFail() }
        let started = try await repo.startSession(blocklistId: UUID(), duration: duration, now: Date())

        let onDisk = try await repo.loadActiveSessionFromDisk()
        XCTAssertEqual(onDisk, started)
    }

    // MARK: - Container unavailable

    func testContainerUnavailableFallsBackToNilActiveAndEmptyHistory() {
        let repo = SessionRepositoryImpl(
            activeURLProvider: { throw SessionStoreError.containerUnavailable },
            historyURLProvider: { throw SessionStoreError.containerUnavailable },
            markerURLProvider: { throw SessionStoreError.containerUnavailable },
            appVersion: "test"
        )
        XCTAssertNil(currentActiveSession(from: repo))
        XCTAssertEqual(currentHistory(from: repo), [])
    }

    // MARK: - Typed helpers
    //
    // Using typed helpers instead of a generic currentValue<Output> helper avoids
    // double-optional (SessionRecord??) issues caused by AnyPublisher<SessionRecord?, Never>
    // being wrapped in Output? by a generic function.

    private func currentActiveSession(
        from repo: SessionRepositoryImpl,
        timeout: TimeInterval = 1.0
    ) -> SessionRecord? {
        var captured: SessionRecord?
        var didReceive = false
        let exp = XCTestExpectation(description: "activeSession value")
        let c = repo.activeSessionPublisher.sink { value in
            captured = value
            if !didReceive {
                didReceive = true
                exp.fulfill()
            }
        }
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
        c.cancel()
        return captured
    }

    private func currentHistory(
        from repo: SessionRepositoryImpl,
        timeout: TimeInterval = 1.0
    ) -> [SessionRecord] {
        var captured: [SessionRecord] = []
        var didReceive = false
        let exp = XCTestExpectation(description: "history value")
        let c = repo.historyPublisher.sink { value in
            captured = value
            if !didReceive {
                didReceive = true
                exp.fulfill()
            }
        }
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
        c.cancel()
        return captured
    }
}
