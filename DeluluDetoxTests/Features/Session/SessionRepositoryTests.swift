import Foundation
import Combine
import Testing
@testable import DeluluDetox

@Suite("SessionRepository")
@MainActor
final class SessionRepositoryTests {

    let tempDir: URL
    let activeURL: URL
    let historyURL: URL
    let markerURL: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        activeURL = tempDir.appendingPathComponent("active_session.json")
        historyURL = tempDir.appendingPathComponent("sessions.json")
        markerURL = tempDir.appendingPathComponent("session_finalize_marker.json")
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Fresh container

    @Test("init on fresh container returns nil active and empty history via publishers")
    func initOnFreshContainerReturnsNilActiveAndEmptyHistoryViaPublishers() {
        let repo = makeRepo()
        #expect(currentActiveSession(from: repo) == nil)
        #expect(currentHistory(from: repo).isEmpty)
    }

    // MARK: - Start

    @Test("start session writes both files atomically and emits on both publishers")
    func startSessionWritesBothFilesAtomicallyAndEmitsOnBothPublishers() async throws {
        let repo = makeRepo()
        let blocklistId = UUID()
        let duration = try #require(SessionDuration.preset(30), "preset 30 nil")
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let record = try await repo.startSession(blocklistId: blocklistId, duration: duration, now: now)

        #expect(FileManager.default.fileExists(atPath: activeURL.path))
        #expect(FileManager.default.fileExists(atPath: historyURL.path))

        let activeDecoded = try JSONDecoder().decode(SessionRecord.self, from: Data(contentsOf: activeURL))
        #expect(activeDecoded == record)
        #expect(activeDecoded.isActive)

        let historyDecoded = try JSONDecoder().decode([SessionRecord].self, from: Data(contentsOf: historyURL))
        #expect(historyDecoded.count == 1)
        #expect(historyDecoded.first == record)

        #expect(currentActiveSession(from: repo) == record)
        #expect(currentHistory(from: repo) == [record])

        #expect(record.plannedEndAt.timeIntervalSince1970 - now.timeIntervalSince1970 == TimeInterval(30 * 60))
        #expect(record.plannedDurationSeconds == 30 * 60)
        #expect(record.blocklistId == blocklistId)
        #expect(record.appVersion == "test")
    }

    // MARK: - Finalize

    @Test("finalize active session updates history record and deletes active file")
    func finalizeActiveSessionUpdatesHistoryRecordAndDeletesActiveFile() async throws {
        let repo = makeRepo()
        let duration = try #require(SessionDuration.preset(30))
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let started = try await repo.startSession(blocklistId: UUID(), duration: duration, now: now)

        let end = Date(timeIntervalSince1970: 1_700_001_800)
        try await repo.finalizeActiveSession(outcome: .completed, actualEndAt: end)

        #expect(!FileManager.default.fileExists(atPath: activeURL.path))

        let history = try JSONDecoder().decode([SessionRecord].self, from: Data(contentsOf: historyURL))
        #expect(history.count == 1)
        #expect(history.first?.id == started.id)
        #expect(history.first?.actualEndAt == end)
        #expect(history.first?.outcome == .completed)
        #expect(history.first?.isActive == false)

        #expect(currentActiveSession(from: repo) == nil)
        #expect(currentHistory(from: repo).count == 1)
    }

    @Test("finalize active session throws when none active")
    func finalizeActiveSessionThrowsWhenNoneActive() async {
        let repo = makeRepo()
        do {
            try await repo.finalizeActiveSession(outcome: .completed, actualEndAt: Date())
            Issue.record("expected SessionStoreError.noActiveSession")
        } catch let error as SessionStoreError {
            guard case .noActiveSession = error else {
                Issue.record("wrong case: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }

    // MARK: - Cross-instance persistence

    @Test("persistence across repo instances")
    func persistenceAcrossRepoInstances() async throws {
        let repoA = makeRepo()
        let duration = try #require(SessionDuration.preset(15))
        let started = try await repoA.startSession(blocklistId: UUID(), duration: duration, now: Date())

        let repoB = makeRepo()
        #expect(currentActiveSession(from: repoB)?.id == started.id)
        #expect(currentHistory(from: repoB).count == 1)
    }

    // MARK: - Finalize marker

    @Test("consumeFinalizeMarker deletes marker file after return")
    func consumeFinalizeMarkerDeletesMarkerFileAfterReturn() async throws {
        let repo = makeRepo()
        let marker = SessionFinalizeMarker(
            sessionId: UUID(),
            finalizedAt: Date(),
            source: .damIntervalDidEnd
        )
        try JSONEncoder().encode(marker).write(to: markerURL, options: .atomic)
        #expect(FileManager.default.fileExists(atPath: markerURL.path))

        let returned = try await repo.consumeFinalizeMarker()
        #expect(returned == marker)
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
    }

    @Test("consumeFinalizeMarker returns nil when absent")
    func consumeFinalizeMarkerReturnsNilWhenAbsent() async throws {
        let repo = makeRepo()
        let result = try await repo.consumeFinalizeMarker()
        #expect(result == nil)
    }

    // MARK: - Disk re-read

    @Test("loadActiveSessionFromDisk returns current record after start")
    func loadActiveSessionFromDiskReturnsCurrentRecordAfterStart() async throws {
        let repo = makeRepo()
        let duration = try #require(SessionDuration.preset(15))
        let started = try await repo.startSession(blocklistId: UUID(), duration: duration, now: Date())

        let onDisk = try await repo.loadActiveSessionFromDisk()
        #expect(onDisk == started)
    }

    // MARK: - Container unavailable

    @Test("container unavailable falls back to nil active and empty history")
    func containerUnavailableFallsBackToNilActiveAndEmptyHistory() {
        let repo = SessionRepositoryImpl(
            activeURLProvider: { throw SessionStoreError.containerUnavailable },
            historyURLProvider: { throw SessionStoreError.containerUnavailable },
            markerURLProvider: { throw SessionStoreError.containerUnavailable },
            appVersion: "test"
        )
        #expect(currentActiveSession(from: repo) == nil)
        #expect(currentHistory(from: repo) == [])
    }
}

// MARK: - Private Helpers

private extension SessionRepositoryTests {
    func makeRepo() -> SessionRepositoryImpl {
        SessionRepositoryImpl(
            activeURLProvider: { [activeURL] in activeURL },
            historyURLProvider: { [historyURL] in historyURL },
            markerURLProvider: { [markerURL] in markerURL },
            appVersion: "test"
        )
    }

    func currentActiveSession(from repo: SessionRepositoryImpl) -> SessionRecord? {
        var captured: SessionRecord?
        let c = repo.activeSessionPublisher.sink { captured = $0 }
        c.cancel()
        return captured
    }

    func currentHistory(from repo: SessionRepositoryImpl) -> [SessionRecord] {
        var captured: [SessionRecord] = []
        let c = repo.historyPublisher.sink { captured = $0 }
        c.cancel()
        return captured
    }
}
