import Foundation
import UserNotifications
import os

/// Main-app notification center delegate responsible ONLY for shield-originated
/// deep-link notifications. Receives banner taps, validates the `userInfo["url"]`
/// payload, and forwards to `HomeViewModel.handleDeepLink(_:)` via an injected
/// async handler. The handler is wired in `DeluluDetoxApp.init()` / `AppRootView`
/// to reach `homeModel.handleDeepLink`.
///
/// Safety: only acts on notifications whose identifier starts with
/// `ShieldNotificationDispatcher.identifierPrefix` — other notification sources
/// (future: Phase 6 NTF-01/NTF-02) are ignored here, letting the system pass
/// them through to the default handler.
@MainActor
final class ShieldDeepLinkNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    typealias DeepLinkHandler = @Sendable (URL) async -> Void

    private let handler: DeepLinkHandler
    private let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ShieldDeepLinkNotification"
    )

    init(handler: @escaping DeepLinkHandler) {
        self.handler = handler
        super.init()
    }

    // Show banner while app is in foreground — user may have shield up when
    // the notification fires; banner tap dismisses shield + foregrounds app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier.hasPrefix(ShieldNotificationDispatcher.identifierPrefix) else {
            completionHandler([])
            return
        }
        completionHandler([.banner])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo

        // Fire completionHandler synchronously in every branch so iOS releases
        // the notification handling resources immediately. The actual deep-link
        // routing is fire-and-forget on @MainActor — matches the existing
        // T-04-03-02 pattern used by the shield extension (don't block the
        // system-framework callback on our async work). Swift 6 data-race
        // check: completionHandler is a `@Sendable () -> Void` from iOS, but
        // capturing it into a Task triggers a strict-concurrency false-positive;
        // calling it here keeps the handler non-escaping from our perspective.
        defer { completionHandler() }

        guard identifier.hasPrefix(ShieldNotificationDispatcher.identifierPrefix) else {
            return
        }
        guard let urlString = userInfo[ShieldNotificationDispatcher.userInfoURLKey] as? String,
              let url = URL(string: urlString),
              url.scheme == "deluludetox" else {
            Task { @MainActor [log] in
                log.error("shield deeplink notif tap: invalid userInfo")
            }
            return
        }

        Task { @MainActor [handler, log] in
            log.info("shield deeplink notif tap url=\(url.absoluteString, privacy: .public)")
            await handler(url)
        }
    }
}
