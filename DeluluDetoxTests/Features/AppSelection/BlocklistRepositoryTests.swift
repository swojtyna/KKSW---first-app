import Foundation
import Combine
import FamilyControls
import Testing
@testable import DeluluDetox

@Suite("BlocklistRepository")
@MainActor
final class BlocklistRepositoryTests {

    let tempDir: URL
    let fileURL: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("blocklist-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("blocklists.json")
    }

    deinit {
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("init on fresh container returns empty blocklist via publisher")
    func initOnFreshContainerReturnsEmptyBlocklistViaPublisher() {
        let repo = makeRepo()
        let received = repo.blocklistPublisher.firstValue()
        #expect(received?.records.count == 0)
        #expect(received?.needsRepair == false)
    }

    @Test("update with empty selection persists JSON and emits")
    func updateWithEmptySelectionPersistsJSONAndEmits() async throws {
        let repo = makeRepo()
        try await repo.update(with: FamilyActivitySelection())

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode(Blocklist.self, from: data)
        #expect(decoded.records.count == 0)

        let latest = repo.blocklistPublisher.firstValue()
        #expect(latest?.records.count == 0)
    }

    @Test("persistence across repo instances")
    func persistenceAcrossRepoInstances() async throws {
        let repoA = makeRepo()
        try await repoA.update(with: FamilyActivitySelection())

        let repoB = makeRepo()
        let secondInit = repoB.blocklistPublisher.firstValue()
        #expect(secondInit != nil)
        let onDisk = try JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL))
        #expect(secondInit?.id == onDisk.id)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("reconcile bumps updatedAt and emits")
    func reconcileBumpsUpdatedAtAndEmits() async throws {
        let repo = makeRepo()
        try await repo.update(with: FamilyActivitySelection())
        let before = try JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL))

        try await Task.sleep(nanoseconds: 10_000_000)
        try await repo.reconcile()

        let after = try JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL))
        #expect(after.updatedAt > before.updatedAt)
        #expect(after.records.count == before.records.count)
    }

    @Test("removeRecordID drops record from disk")
    func removeRecordIDDropsRecordFromDisk() async throws {
        var seed = Blocklist.empty()
        let keepID = UUID()
        let dropID = UUID()
        seed.records = [
            TokenRecord(id: keepID, kind: .application, encodedToken: Data([0xAA]), lastSeenAt: Date()),
            TokenRecord(id: dropID, kind: .category,    encodedToken: Data([0xBB]), lastSeenAt: Date()),
        ]
        try JSONEncoder().encode(seed).write(to: fileURL, options: .atomic)

        let freshRepo = makeRepo()
        try await freshRepo.remove(recordID: dropID)

        let onDisk = try JSONDecoder().decode(Blocklist.self, from: Data(contentsOf: fileURL))
        #expect(onDisk.records.map(\.id) == [keepID])
    }

    @Test("container unavailable on init falls back to empty")
    func containerUnavailableOnInitFallsBackToEmpty() {
        let repo = BlocklistRepositoryImpl(fileURLProvider: {
            throw BlocklistStoreError.containerUnavailable
        })
        #expect(repo.blocklistPublisher.firstValue()?.records.count == 0)
    }
}

// MARK: - Private Helpers

private extension BlocklistRepositoryTests {
    func makeRepo() -> BlocklistRepositoryImpl {
        BlocklistRepositoryImpl(fileURLProvider: { [fileURL] in fileURL })
    }
}

private extension Publisher where Failure == Never {
    func firstValue() -> Output? {
        var captured: Output?
        let c = self.sink { captured = $0 }
        c.cancel()
        return captured
    }
}
