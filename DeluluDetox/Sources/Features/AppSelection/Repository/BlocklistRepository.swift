import Combine
@preconcurrency import FamilyControls
import Foundation
import ManagedSettings
import os

// MARK: - Protocol

protocol BlocklistRepository: Sendable {
    var blocklistPublisher: AnyPublisher<Blocklist, Never> { get }
    func update(with selection: FamilyActivitySelection) async throws
    func remove(recordID: TokenRecord.ID) async throws
    func reconcile() async throws
}

// MARK: - Errors

enum BlocklistStoreError: Error {
    case containerUnavailable
}

// MARK: - Implementation

final class BlocklistRepositoryImpl: BlocklistRepository, @unchecked Sendable {
    // MARK: Configuration

    /// Container identifier — matches `DeluluDetox.entitlements` + project.yml.
    /// Exposed internal so unit tests can run against a custom base URL injection
    /// point (see init overload).
    static let appGroupIdentifier = "group.com.kksw.DeluluDetox"
    static let fileName = "blocklists.json"

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "BlocklistRepository"
    )

    // MARK: State

    private let blocklistSubject: CurrentValueSubject<Blocklist, Never>
    private let fileURLProvider: @Sendable () throws -> URL

    var blocklistPublisher: AnyPublisher<Blocklist, Never> {
        blocklistSubject.eraseToAnyPublisher()
    }

    // MARK: Init

    /// Production init — resolves App Group container URL.
    convenience init() {
        self.init(fileURLProvider: {
            guard let base = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            ) else {
                throw BlocklistStoreError.containerUnavailable
            }
            return base.appendingPathComponent(Self.fileName, isDirectory: false)
        })
    }

    /// Test seam — allow tests to inject a temporary-directory URL without
    /// depending on the real App Group container (which is not mounted in
    /// XCTest runs).
    init(fileURLProvider: @escaping @Sendable () throws -> URL) {
        self.fileURLProvider = fileURLProvider
        let initial = Self.readFromDisk(using: fileURLProvider) ?? Blocklist.empty()
        self.blocklistSubject = CurrentValueSubject(initial)
    }

    // MARK: Mutations

    func update(with selection: FamilyActivitySelection) async throws {
        let current = blocklistSubject.value
        let next = current.merging(selection: selection)
        try writeAndEmit(next)
    }

    func remove(recordID: TokenRecord.ID) async throws {
        var current = blocklistSubject.value
        current.records.removeAll { $0.id == recordID }
        current.updatedAt = Date()
        try writeAndEmit(current)
    }

    func reconcile() async throws {
        let current = blocklistSubject.value
        let reconciled = current.reconcileTokenPointers()
        try writeAndEmit(reconciled)
    }

    // MARK: I/O helpers

    private func writeAndEmit(_ blocklist: Blocklist) throws {
        let url = try fileURLProvider()
        let data = try JSONEncoder().encode(blocklist)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        Self.log.info(
            "blocklist written bytes=\(data.count, privacy: .public) records=\(blocklist.records.count, privacy: .public)"
        )
        blocklistSubject.send(blocklist)
    }

    private static func readFromDisk(
        using fileURLProvider: @Sendable () throws -> URL
    ) -> Blocklist? {
        do {
            let url = try fileURLProvider()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Blocklist.self, from: data)
        } catch {
            log.error("read failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
