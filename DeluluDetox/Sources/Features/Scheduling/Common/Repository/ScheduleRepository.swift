import Combine
import Foundation
import os

// MARK: - Errors

enum ScheduleStoreError: Error {
    case scheduleNotFound
    case pathsUnavailable
}

// MARK: - Implementation

/// Atomic JSON persistence for the Scheduling feature.
///
/// Mirrors `SessionRepositoryImpl`: 4-closure URL-provider seam for tests,
/// `CurrentValueSubject<[Schedule], Never>` surfaced through
/// `schedulesPublisher`, and `[.atomic, .completeFileProtectionUntilFirstUserAuthentication]`
/// on every write.
///
/// The multi-marker `consumeEventMarkers()` resolves RESEARCH OQ#4: the
/// original `D-17` single-file overwrite cannot survive a cross-midnight
/// schedule (evening-start immediately followed by morning-end with no
/// foreground between them). Each marker lives in its own
/// `schedule_event_marker_{unix_ms}.json` file; the repository lists,
/// sorts by the filename's unix-millis suffix, appends to
/// `schedule_events.json`, then deletes the marker files.
final class ScheduleRepositoryImpl: ScheduleRepository, @unchecked Sendable {
    typealias URLProvider = @Sendable () throws -> URL

    // MARK: Paths (test-injectable)
    private let schedulesURLProvider: URLProvider
    private let eventsURLProvider: URLProvider
    private let markerDirectoryURLProvider: URLProvider

    // MARK: Audit
    private let appVersion: String

    // MARK: Logger
    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ScheduleRepository"
    )

    // MARK: State
    private let schedulesSubject: CurrentValueSubject<[Schedule], Never>

    // MARK: Publisher
    var schedulesPublisher: AnyPublisher<[Schedule], Never> {
        schedulesSubject.eraseToAnyPublisher()
    }

    // MARK: - Init (production)

    convenience init() {
        self.init(
            schedulesURLProvider: { try SchedulePaths.schedulesURL() },
            eventsURLProvider: { try SchedulePaths.eventsURL() },
            markerDirectoryURLProvider: { try SchedulePaths.markerDirectoryURL() },
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        )
    }

    // MARK: - Init (test seam)

    init(
        schedulesURLProvider: @escaping URLProvider,
        eventsURLProvider: @escaping URLProvider,
        markerDirectoryURLProvider: @escaping URLProvider,
        appVersion: String
    ) {
        self.schedulesURLProvider = schedulesURLProvider
        self.eventsURLProvider = eventsURLProvider
        self.markerDirectoryURLProvider = markerDirectoryURLProvider
        self.appVersion = appVersion

        let seed = Self.readList(using: schedulesURLProvider, type: [Schedule].self) ?? []
        self.schedulesSubject = CurrentValueSubject(seed)
    }

    // MARK: - Mutations

    func upsert(_ schedule: Schedule) async throws {
        var current = schedulesSubject.value
        if let idx = current.firstIndex(where: { $0.id == schedule.id }) {
            current[idx] = schedule
        } else {
            current.append(schedule)
        }
        try writeAtomic(current, to: try schedulesURLProvider())
        schedulesSubject.send(current)

        Self.log.info(
            "schedule upserted id=\(schedule.id.uuidString, privacy: .public) enabled=\(schedule.enabled, privacy: .public) count=\(current.count, privacy: .public)"
        )
    }

    func remove(id: UUID) async throws {
        var current = schedulesSubject.value
        guard let idx = current.firstIndex(where: { $0.id == id }) else {
            Self.log.error("remove failed — schedule not found id=\(id.uuidString, privacy: .public)")
            throw ScheduleStoreError.scheduleNotFound
        }
        current.remove(at: idx)
        try writeAtomic(current, to: try schedulesURLProvider())
        schedulesSubject.send(current)

        Self.log.info(
            "schedule removed id=\(id.uuidString, privacy: .public) remaining=\(current.count, privacy: .public)"
        )
    }

    func loadFromDisk() async throws -> [Schedule] {
        let url = try schedulesURLProvider()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Schedule].self, from: data)
    }

    // MARK: - Events (append-only history)

    func appendEvent(_ event: ScheduleEvent) async throws {
        let url = try eventsURLProvider()
        var events = Self.readList(using: { url }, type: [ScheduleEvent].self) ?? []
        events.append(event)
        try writeAtomic(events, to: url)
        Self.log.info(
            "event appended kind=\(event.kind.rawValue, privacy: .public) total=\(events.count, privacy: .public)"
        )
    }

    // MARK: - Marker consume (RESEARCH OQ#4)

    func consumeEventMarkers() async throws -> [ScheduleEventMarker] {
        let dir = try markerDirectoryURLProvider()
        // If directory missing, nothing to consume.
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }

        let entries = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let markerURLs = entries.filter { SchedulePaths.isMarkerFile($0) }
        if markerURLs.isEmpty { return [] }

        // Pair each URL with its filename suffix (unix millis). Drop unparseable.
        let paired: [(ms: Int64, url: URL)] = markerURLs.compactMap { url in
            guard let ms = Self.parseMarkerTimestamp(from: url) else {
                Self.log.error("skipping marker with unparseable suffix name=\(url.lastPathComponent, privacy: .public)")
                return nil
            }
            return (ms, url)
        }.sorted { $0.ms < $1.ms }

        var consumed: [ScheduleEventMarker] = []
        consumed.reserveCapacity(paired.count)

        for (_, url) in paired {
            do {
                let data = try Data(contentsOf: url)
                let marker = try JSONDecoder().decode(ScheduleEventMarker.self, from: data)
                consumed.append(marker)
                try FileManager.default.removeItem(at: url)
            } catch {
                // Log and continue — next run picks up any remaining markers.
                Self.log.error(
                    "marker decode/remove failed name=\(url.lastPathComponent, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        Self.log.info("markers consumed count=\(consumed.count, privacy: .public)")
        return consumed
    }

    // MARK: - I/O helpers

    private func writeAtomic<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func readList<T: Decodable>(
        using urlProvider: URLProvider,
        type: T.Type
    ) -> T? {
        do {
            let url = try urlProvider()
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log.error(
                "readList failed type=\(String(describing: T.self), privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private static func parseMarkerTimestamp(from url: URL) -> Int64? {
        let name = url.lastPathComponent
        guard name.hasPrefix(SchedulePaths.markerFilePrefix),
              name.hasSuffix(SchedulePaths.markerFileSuffix)
        else { return nil }
        let start = name.index(name.startIndex, offsetBy: SchedulePaths.markerFilePrefix.count)
        let end = name.index(name.endIndex, offsetBy: -SchedulePaths.markerFileSuffix.count)
        guard start <= end else { return nil }
        return Int64(name[start..<end])
    }
}
