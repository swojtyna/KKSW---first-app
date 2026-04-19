import Combine
import Foundation
import os

// MARK: - Protocol

protocol SessionRepository: Sendable {
    var activeSessionPublisher: AnyPublisher<SessionRecord?, Never> { get }
    var historyPublisher: AnyPublisher<[SessionRecord], Never> { get }

    /// Create and persist a new active SessionRecord. Returns the freshly-created record.
    /// Writes `active_session.json` AND appends to `sessions.json` atomically.
    func startSession(
        blocklistId: UUID,
        duration: SessionDuration,
        now: Date
    ) async throws -> SessionRecord

    /// Finalize the currently active session. Updates the matching record in
    /// `sessions.json` and deletes `active_session.json`. Throws `noActiveSession`
    /// if there is no active session.
    func finalizeActiveSession(
        outcome: SessionOutcome,
        actualEndAt: Date
    ) async throws

    /// Read + delete the DAM-written finalize marker. Returns nil if absent.
    func consumeFinalizeMarker() async throws -> SessionFinalizeMarker?

    /// Defense-in-depth read for AppRoot self-heal (CONTEXT §D-02): re-reads
    /// `active_session.json` directly from disk in case the in-memory subject
    /// was reset between the main-app process and an out-of-band write.
    func loadActiveSessionFromDisk() async throws -> SessionRecord?
}

// MARK: - Errors

enum SessionStoreError: Error {
    case containerUnavailable
    case noActiveSession
}

// MARK: - Implementation

final class SessionRepositoryImpl: SessionRepository, @unchecked Sendable {
    typealias URLProvider = @Sendable () throws -> URL

    // MARK: Paths
    private let activeURLProvider: URLProvider
    private let historyURLProvider: URLProvider
    private let markerURLProvider: URLProvider

    // MARK: Logger
    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SessionRepository"
    )

    // MARK: State
    private let activeSubject: CurrentValueSubject<SessionRecord?, Never>
    private let historySubject: CurrentValueSubject<[SessionRecord], Never>

    // MARK: App version (stamped onto every new SessionRecord).
    private let appVersion: String

    // MARK: Publishers
    var activeSessionPublisher: AnyPublisher<SessionRecord?, Never> {
        activeSubject.eraseToAnyPublisher()
    }
    var historyPublisher: AnyPublisher<[SessionRecord], Never> {
        historySubject.eraseToAnyPublisher()
    }

    // MARK: Init (production)
    convenience init() {
        self.init(
            activeURLProvider: { try SessionPaths.activeSessionURL() },
            historyURLProvider: { try SessionPaths.historyURL() },
            markerURLProvider: { try SessionPaths.finalizeMarkerURL() },
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        )
    }

    // MARK: Init (test seam)
    init(
        activeURLProvider: @escaping URLProvider,
        historyURLProvider: @escaping URLProvider,
        markerURLProvider: @escaping URLProvider,
        appVersion: String
    ) {
        self.activeURLProvider = activeURLProvider
        self.historyURLProvider = historyURLProvider
        self.markerURLProvider = markerURLProvider
        self.appVersion = appVersion

        let initialActive = Self.readSingle(using: activeURLProvider, type: SessionRecord.self)
        let initialHistory = Self.readSingle(using: historyURLProvider, type: [SessionRecord].self) ?? []

        self.activeSubject = CurrentValueSubject(initialActive)
        self.historySubject = CurrentValueSubject(initialHistory)
    }

    // MARK: - Mutations

    func startSession(
        blocklistId: UUID,
        duration: SessionDuration,
        now: Date
    ) async throws -> SessionRecord {
        let record = SessionRecord(
            id: UUID(),
            blocklistId: blocklistId,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(TimeInterval(duration.seconds)),
            plannedDurationSeconds: duration.seconds,
            actualEndAt: nil,
            outcome: nil,
            appVersion: appVersion
        )

        // Write active_session.json (singleton).
        try writeAtomic(record, to: try activeURLProvider())

        // Append to sessions.json (history).
        var history = historySubject.value
        history.append(record)
        try writeAtomic(history, to: try historyURLProvider())

        // Emit on both subjects.
        activeSubject.send(record)
        historySubject.send(history)

        Self.log.info("session started id=\(record.id.uuidString, privacy: .public) duration=\(duration.seconds, privacy: .public)")
        return record
    }

    func finalizeActiveSession(
        outcome: SessionOutcome,
        actualEndAt: Date
    ) async throws {
        guard let active = activeSubject.value else {
            throw SessionStoreError.noActiveSession
        }

        // Update the matching record in history.
        var history = historySubject.value
        guard let idx = history.firstIndex(where: { $0.id == active.id }) else {
            throw SessionStoreError.noActiveSession
        }
        history[idx].actualEndAt = actualEndAt
        history[idx].outcome = outcome

        // Write history first, then delete the active file.
        try writeAtomic(history, to: try historyURLProvider())
        try? FileManager.default.removeItem(at: try activeURLProvider())

        activeSubject.send(nil)
        historySubject.send(history)

        Self.log.info("session finalized id=\(active.id.uuidString, privacy: .public) outcome=\(outcome.rawValue, privacy: .public)")
    }

    func consumeFinalizeMarker() async throws -> SessionFinalizeMarker? {
        let url = try markerURLProvider()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let marker = try JSONDecoder().decode(SessionFinalizeMarker.self, from: data)
        try? FileManager.default.removeItem(at: url)
        return marker
    }

    func loadActiveSessionFromDisk() async throws -> SessionRecord? {
        let url = try activeURLProvider()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SessionRecord.self, from: data)
    }

    // MARK: - I/O helpers

    private func writeAtomic<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func readSingle<T: Decodable>(
        using urlProvider: URLProvider,
        type: T.Type
    ) -> T? {
        do {
            let url = try urlProvider()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log.error("readSingle failed type=\(String(describing: T.self), privacy: .public) error=\(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
