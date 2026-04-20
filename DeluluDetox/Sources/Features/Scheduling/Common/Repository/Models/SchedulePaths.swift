import Foundation

/// App Group file URL helpers shared with DeviceActivityMonitor extension
/// (CONTEXT §D-04, §D-17 — marker overwrite fix from RESEARCH OQ#4).
///
/// Extension target imports only this file + its siblings under `Models/`
/// — no SwiftUI, no Combine, no FamilyControls.
///
/// Marker filename convention: `schedule_event_marker_{unix_millis}.json`.
/// Multiple markers coexist; main-app lists the App Group directory,
/// filters via `isMarkerFile(_:)`, decodes each, sorts by timestamp, then
/// deletes after appending to `schedule_events.json`.
enum SchedulePaths {
    static let appGroupIdentifier = "group.com.kksw.DeluluDetox"
    static let schedulesFileName = "schedule.json"
    static let eventsFileName = "schedule_events.json"
    static let markerFilePrefix = "schedule_event_marker_"
    static let markerFileSuffix = ".json"

    enum PathError: Error { case containerUnavailable }

    private static func containerURL() throws -> URL {
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw PathError.containerUnavailable
        }
        return base
    }

    static func schedulesURL() throws -> URL {
        try containerURL().appendingPathComponent(schedulesFileName, isDirectory: false)
    }

    static func eventsURL() throws -> URL {
        try containerURL().appendingPathComponent(eventsFileName, isDirectory: false)
    }

    /// Timestamp-suffixed marker file (unix milliseconds).
    /// Multiple markers can coexist; main app lists, sorts by suffix, consumes.
    static func markerURL(timestamp: Date) throws -> URL {
        let ms = Int64(timestamp.timeIntervalSince1970 * 1000)
        return try containerURL().appendingPathComponent(
            "\(markerFilePrefix)\(ms)\(markerFileSuffix)",
            isDirectory: false
        )
    }

    /// Directory (App Group root) to scan for marker files.
    static func markerDirectoryURL() throws -> URL { try containerURL() }

    /// True iff `url.lastPathComponent` matches the marker naming convention.
    static func isMarkerFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix(markerFilePrefix) && name.hasSuffix(markerFileSuffix)
    }
}
