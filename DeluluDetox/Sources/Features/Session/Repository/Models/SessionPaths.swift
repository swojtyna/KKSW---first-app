import Foundation

/// Central App Group file URL helpers shared between the main app and the
/// DeviceActivityMonitor extension (CONTEXT §D-13). Extension target imports
/// only this file + its siblings under `Models/` — no SwiftUI, no Combine.
enum SessionPaths {
    static let appGroupIdentifier = "group.com.kksw.DeluluDetox"
    static let activeSessionFileName = "active_session.json"
    static let historyFileName = "sessions.json"
    static let finalizeMarkerFileName = "session_finalize_marker.json"

    enum PathError: Error { case containerUnavailable }

    private static func containerURL() throws -> URL {
        guard let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw PathError.containerUnavailable
        }
        return base
    }

    static func activeSessionURL() throws -> URL {
        try containerURL().appendingPathComponent(activeSessionFileName, isDirectory: false)
    }

    static func historyURL() throws -> URL {
        try containerURL().appendingPathComponent(historyFileName, isDirectory: false)
    }

    static func finalizeMarkerURL() throws -> URL {
        try containerURL().appendingPathComponent(finalizeMarkerFileName, isDirectory: false)
    }
}
