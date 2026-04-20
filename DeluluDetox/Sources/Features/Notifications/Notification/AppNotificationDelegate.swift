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
    /// to this when called from iOS. Shield deep-link prefix validates the
    /// extracted `urlString` has scheme `deluludetox` before forwarding to the
    /// handler. Other prefixes (NTF-01 / NTF-02) are no-ops — iOS
    /// auto-foregrounds the app on tap.
    ///
    /// Takes a pre-extracted `urlString: String?` (Sendable) rather than the raw
    /// `[AnyHashable: Any]` userInfo dictionary. iOS can place non-Sendable
    /// reference types (NSNumber, NSDate, CFType bridges) inside userInfo, so
    /// the caller (`didReceive`) extracts the single String value we need on
    /// the nonisolated queue before hopping actors — no `@unchecked Sendable`
    /// box required.
    func dispatchResponse(identifier: String, urlString: String?) async {
        guard identifier.hasPrefix(ShieldNotificationConstants.identifierPrefix) else {
            // Phase 6 engagement notification taps just foreground the app
            // (iOS does that automatically). No routing in MVP.
            return
        }
        guard let urlString,
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
        // Extract the single String value we care about synchronously on the
        // nonisolated queue BEFORE hopping actors. This avoids boxing the raw
        // `[AnyHashable: Any]` userInfo dictionary in an `@unchecked Sendable`
        // wrapper — iOS can place non-Sendable reference types inside userInfo
        // and a blanket `@unchecked Sendable` promise silently masks future
        // regressions if any call-site writes non-String values.
        let urlString = response.notification.request.content.userInfo[
            ShieldNotificationConstants.userInfoURLKey
        ] as? String
        // Fire completionHandler synchronously so iOS releases the
        // notification handling resources immediately (T-04-03-02 pattern).
        defer { completionHandler() }

        // Forward to the @MainActor seam. Fire-and-forget — we don't block
        // the iOS callback on our async work.
        Task { @MainActor [self] in
            await dispatchResponse(identifier: id, urlString: urlString)
        }
    }
}
