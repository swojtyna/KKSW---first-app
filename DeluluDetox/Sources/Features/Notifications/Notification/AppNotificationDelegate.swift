import Foundation
import UserNotifications
import os

/// Composite `UNUserNotificationCenterDelegate` for the main app.
/// Dispatches by `UNNotification.request.identifier` prefix:
///
/// - `ShieldNotificationConstants.identifierPrefix` ("com.kksw.DeluluDetox.shield-deeplink.")
///   → Phase 4 SHL-03 behavior: foreground banner; tap validates `userInfo["url"]`
///     and forwards via the injected async handler.
/// - `"session.end."` → Phase 6 NTF-01. Foreground: `[]` (silent; success screen
///   already shown — RESEARCH §Pitfall 4).
/// - `"schedule.start."` → Phase 6 NTF-02. Foreground: `[.banner, .sound]`
///   (user needs to know blocking started; §H4 recommendation).
/// - Any other prefix → `[]` (default deny).
///
/// REPLACES `Features/Shield/Notification/ShieldDeepLinkNotificationDelegate.swift`
/// — that file is left on disk for reference but no longer referenced by
/// `DeluluDetoxApp.init()` (Plan 02 Task 4).
@MainActor
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    typealias DeepLinkHandler = @Sendable (URL) async -> Void

    private let shieldDeepLinkHandler: DeepLinkHandler
    private let log = Logger(subsystem: "com.kksw.DeluluDetox", category: "AppNotificationDelegate")

    init(shieldDeepLinkHandler: @escaping DeepLinkHandler) {
        self.shieldDeepLinkHandler = shieldDeepLinkHandler
        super.init()
    }

    // MARK: - Test seams (internal)

    /// Pure identifier-prefix → presentation options mapping.
    /// The public `willPresent` forwards to this. Exists to enable unit testing
    /// without constructing `UNNotification` (no public initializer).
    func presentationOptions(forIdentifier id: String) -> UNNotificationPresentationOptions {
        if id.hasPrefix(ShieldNotificationConstants.identifierPrefix) { return [.banner] }
        if id.hasPrefix("session.end.") { return [] }
        if id.hasPrefix("schedule.start.") { return [.banner, .sound] }
        return []
    }

    /// Pure tap-response dispatch used by tests. The public `didReceive` forwards
    /// to this when called from iOS. Shield deep-link prefix validates `userInfo["url"]`
    /// has scheme `deluludetox` before forwarding to the handler. Other prefixes
    /// (NTF-01 / NTF-02) are no-ops — iOS auto-foregrounds the app on tap.
    func dispatchResponse(identifier: String, userInfo: [AnyHashable: Any]) async {
        guard identifier.hasPrefix(ShieldNotificationConstants.identifierPrefix) else {
            // Phase 6 engagement notification taps just foreground the app
            // (iOS does that automatically). No routing in MVP.
            return
        }
        guard let urlString = userInfo[ShieldNotificationConstants.userInfoURLKey] as? String,
              let url = URL(string: urlString),
              url.scheme == "deluludetox" else {
            log.error("shield deeplink notif tap: invalid userInfo")
            return
        }
        log.info("shield deeplink notif tap url=\(url.absoluteString, privacy: .public)")
        await shieldDeepLinkHandler(url)
    }

    // MARK: - Foreground presentation

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id = notification.request.identifier
        let options = MainActor.assumeIsolated { presentationOptions(forIdentifier: id) }
        completionHandler(options)
    }

    // MARK: - Tap response

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        // Fire completionHandler synchronously so iOS releases the
        // notification handling resources immediately (T-04-03-02 pattern).
        defer { completionHandler() }

        // Forward to the @MainActor seam. Fire-and-forget — we don't block
        // the iOS callback on our async work.
        let sendableUserInfo = _SendableUserInfo(userInfo)
        Task { @MainActor [self] in
            await dispatchResponse(identifier: id, userInfo: sendableUserInfo.value)
        }
    }
}

/// Narrow Sendable box for `userInfo` payload. iOS hands us a
/// `[AnyHashable: Any]` that isn't `Sendable`; tests only use `String`
/// values so this box is safe in practice for MVP. Future: validate the
/// dictionary shape before boxing.
private struct _SendableUserInfo: @unchecked Sendable {
    let value: [AnyHashable: Any]
    init(_ value: [AnyHashable: Any]) { self.value = value }
}
