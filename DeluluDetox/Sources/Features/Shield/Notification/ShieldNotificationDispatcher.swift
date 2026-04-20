import Foundation
import UserNotifications
import os

/// Pure builder + dispatcher for SHL-03 fallback. The extension uses
/// `makeRequest(url:)` to build a `UNNotificationRequest` and `dispatch(url:log:)`
/// to schedule it via `UNUserNotificationCenter.current().add(_:)`.
///
/// Kept deliberately simple and dependency-free so it can be source-shared
/// into `ShieldActionExtension` without inflating the 6 MB RAM ceiling
/// (D-17). Imports: Foundation + UserNotifications + os only.
///
/// Why local notification instead of direct URL open from extension:
/// `ShieldActionDelegate` inherits from `NSObject` and exposes no
/// `extensionContext`; the UIApplication runtime workaround is an App
/// Store Guideline 2.5.1 rejection risk (see 04-03-SUMMARY.md
/// §Post-Review Correction). Local notification is the canonical
/// fallback documented in 04-RESEARCH.md Standard Stack §Alternatives.
struct ShieldNotificationDispatcher {
    static let identifierPrefix = "com.kksw.DeluluDetox.shield-deeplink."
    static let userInfoURLKey = "url"
    static let notificationTitle = "DeluluDetox"
    static let notificationBody = "Dotknij, żeby wrócić do aplikacji."

    func makeRequest(url: URL) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = Self.notificationTitle
        content.body = Self.notificationBody
        content.sound = nil
        content.userInfo = [Self.userInfoURLKey: url.absoluteString]
        let identifier = Self.identifierPrefix + UUID().uuidString
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
    }

    /// Best-effort schedule. Any UN* failure is logged and swallowed —
    /// the shield extension MUST NOT block `completionHandler(.close)` on
    /// notification success, per T-04-03-02 (shield process leak).
    func dispatch(url: URL, log: Logger) {
        let request = makeRequest(url: url)
        // Capture identifier as a Sendable String so the completion closure
        // does not cross-thread-capture the non-Sendable UNNotificationRequest
        // (Swift 6 strict concurrency). iOS 26 still has UNNotificationRequest
        // annotated without @Sendable; this hop keeps the telemetry log safe.
        let capturedIdentifier = request.identifier
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("shield deeplink notif schedule failed: \(String(describing: error), privacy: .public)")
            } else {
                log.info("shield deeplink notif scheduled id=\(capturedIdentifier, privacy: .public)")
            }
        }
    }
}
