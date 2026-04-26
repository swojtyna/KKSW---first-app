import XCTest
import Combine
import FamilyControls
@testable import DeluluDetox

@MainActor
final class BlocklistRepositoryTests: XCTestCase {

    private var tempDir: URL!
    private var fileURL: URL!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("blocklist-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("blocklists.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        cancellables.removeAll()
        try await super.tearDown()
    }

    private func makeRepo() -> BlocklistRepositoryImpl {
        BlocklistRepositoryImpl(fileURLProvider: { [fileURL] in fileURL! })
    }

    // MARK: Tests

    func testInitOnFreshContainerReturnsEmptyBlocklistViaPublisher() async {
        let repo = makeRepo()
        let exp = expectation(description: "initial emission")
        var received: Blocklist?
        repo.blocklistPublisher
            .sink { value in
                received = value
                exp.fulfill()
            }
            .store(in: &cancellables)
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(received?.records.count, 0)
        XCTAssertFalse(received?.needsRepair ?? true)
    }

    func testUpdateWithEmptySelectionPersistsJSONAndEmits() async throws {
        let repo = makeRepo()
        try await repo.update(with: FamilyActivitySelection())

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode(Blocklist.self, from: data)
        XCTAssertEqual(decoded.records.count, 0)

        // Verify publisher re-emits current value.
        let received = repo.blocklistPublisher
        var latest: Blocklist?
        let exp = expectation(description: "latest emission")
        received.sink { v in latest = v; exp.fulfill() }.store(in: &cancellables)
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(latest?.records.count, 0)
    }

    func testPersistenceAcrossRepoInstances() async throws {
        let repoA = makeRepo()
        try await repoA.update(with: FamilyActivitySelection())

        // New instance reading the same file.
        let repoB = makeRepo()
        let secondInit = repoB.blocklistPublisher.value(timeout: 1.0)
        XCTAssertNotNil(secondInit)
        XCTAssertEqual(secondInit?.id, (try? JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL)))?.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testReconcileBumpsUpdatedAtAndEmits() async throws {
        let repo = makeRepo()
        try await repo.update(with: FamilyActivitySelection())
        let before = try JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL))

        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        try await repo.reconcile()

        let after = try JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL))
        XCTAssertGreaterThan(after.updatedAt, before.updatedAt)
        XCTAssertEqual(after.records.count, before.records.count)
    }

    func testRemoveRecordIDDropsRecordFromDisk() async throws {
        // Seed a Blocklist directly on disk to bypass the need for real tokens.
        var seed = Blocklist.empty()
        let keepID = UUID()
        let dropID = UUID()
        seed.records = [
            TokenRecord(id: keepID, kind: .application, encodedToken: Data([0xAA]), lastSeenAt: Date()),
            TokenRecord(id: dropID, kind: .category,    encodedToken: Data([0xBB]), lastSeenAt: Date()),
        ]
        try JSONEncoder().encode(seed).write(to: fileURL, options: .atomic)

        // Spin a fresh repo so it hydrates from disk, then remove.
        let freshRepo = makeRepo()
        try await freshRepo.remove(recordID: dropID)

        let onDisk = try JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL))
        XCTAssertEqual(onDisk.records.map(\.id), [keepID])
    }

    func testContainerUnavailableOnInitFallsBackToEmpty() {
        let repo = BlocklistRepositoryImpl(fileURLProvider: {
            throw BlocklistStoreError.containerUnavailable
        })
        XCTAssertEqual(repo.blocklistPublisher.value(timeout: 1.0)?.records.count, 0)
    }
}

// Small helper to pull the latest synchronous value from a CurrentValueSubject-backed publisher.
private extension Publisher where Failure == Never {
    func value(timeout: TimeInterval) -> Output? {
        var captured: Output?
        let exp = XCTestExpectation(description: "publisher value")
        let cancellable = self.sink { v in
            captured = v
            exp.fulfill()
        }
        _ = XCTWaiter.wait(for: [exp], timeout: timeout)
        cancellable.cancel()
        return captured
    }
}
