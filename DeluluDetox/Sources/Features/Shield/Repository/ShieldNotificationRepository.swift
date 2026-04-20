import Foundation
import UserNotifications
import os

// MARK: - Constants

/// Shared string contract between the extension side (scheduling) and the
/// main-app delegate (filtering). Exposing these as a module-level enum
/// keeps them accessible without coupling the delegate to a specific
/// repository implementation — mirrors how `SessionActivityNames` is
/// shared across Session targets.
enum ShieldNotificationConstants {
    static let identifierPrefix = "com.kksw.DeluluDetox.shield-deeplink."
    static let userInfoURLKey = "url"
    static let notificationTitle = "DeluluDetox"
    static let notificationBody = "Dotknij, żeby wrócić do aplikacji."
}

// MARK: - Protocol

/// Data-layer facade over `UNUserNotificationCenter` for the SHL-03 fallback.
/// `ShieldActionExtension` calls `dispatch(url:log:)` fire-and-forget; the
/// main-app `ShieldDeepLinkNotificationDelegate` observes taps and routes via
/// `HomeViewModel.handleDeepLink(_:)`.
///
/// Source-shared into `ShieldActionExtension` via project.yml — the extension
/// target must keep imports minimal (Foundation + UserNotifications + os) to
/// respect the 6 MB RAM ceiling (D-17). No Live-only code (OS logging only,
/// no UIKit, no SwiftUI).
protocol ShieldNotificationRepository: Sendable {
    /// Build a `UNNotificationRequest` carrying the deep-link URL in
    /// `userInfo["url"]`. Exposed separately from `dispatch` for XCTest
    /// assertions over the request contract.
    func makeRequest(url: URL) -> UNNotificationRequest

    /// Best-effort schedule. Any UN* failure is logged and swallowed —
    /// the shield extension MUST NOT block `completionHandler(.close)` on
    /// notification success, per T-04-03-02 (shield process leak).
    func dispatch(url: URL, log: Logger)
}

// MARK: - Implementation

/// Stateless UN scheduler. Kept `struct` + dependency-free so the extension
/// can instantiate it inline without DI machinery (DIContainer does not run
/// inside app-extension targets).
struct LiveShieldNotificationRepository: ShieldNotificationRepository {

    func makeRequest(url: URL) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = ShieldNotificationConstants.notificationTitle
        content.body = ShieldNotificationConstants.notificationBody
        content.sound = nil
        content.userInfo = [ShieldNotificationConstants.userInfoURLKey: url.absoluteString]
        let identifier = ShieldNotificationConstants.identifierPrefix + UUID().uuidString
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
    }

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
