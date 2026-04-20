import Foundation
import ManagedSettings
import UserNotifications
import os

/// SHL-03 — shield action handler. All overrides delegate to
/// `handle(action:completionHandler:)` per CONTEXT §D-15. Pure decision
/// logic lives in `ShieldActionHandler` (main-app target, source-shared
/// via project.yml) so it can be XCTest-unit-tested.
///
/// Read-only against App Group files (D-16). Imports limited to
/// Foundation + ManagedSettings + UserNotifications + os to respect the
/// 6 MB extension RAM ceiling (D-17, PROJECT.md Hard Constraint §8).
/// UserNotifications is a system framework needed for the SHL-03 local-push
/// fallback (ShieldNotificationDispatcher.dispatch).
final class ShieldActionExtension: ShieldActionDelegate {

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox.ShieldActionExtension",
        category: "ShieldAction"
    )

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, completionHandler: completionHandler)
    }

    // MARK: - Private — shared handler

    private func handle(
        action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let kind = mapActionKind(action)
        let hasActive = ShieldActionSessionProbe.hasActiveSession()
        let decision = ShieldActionHandler().decide(action: kind, hasActiveSession: hasActive)

        Self.log.info(
            "decide kind=\(String(describing: kind), privacy: .public) hasActive=\(hasActive, privacy: .public) urlPresent=\(decision.urlToOpen != nil, privacy: .public)"
        )

        // SHL-03: dispatch via local notification fallback. `ShieldActionDelegate`
        // has no extensionContext and UIApplication workarounds are App Store 2.5.1
        // risk (see 04-03-SUMMARY.md §Post-Review Correction). A silent-ish
        // UNNotificationRequest (no sound, generic copy, no PII) is scheduled
        // immediately; the main app's UNUserNotificationCenterDelegate converts
        // a banner tap into HomeViewModel.handleDeepLink(_:).
        //
        // Fire-and-forget: UNUserNotificationCenter.add is async but we do NOT
        // await it — completionHandler(.close) fires unconditionally below so
        // the shield process is always released (T-04-03-02 mitigation retained).
        if let url = decision.urlToOpen {
            LiveShieldNotificationRepository().dispatch(url: url, log: Self.log)
        }

        // Always respond — even if open(_:) fails, completionHandler must fire
        // so iOS releases the shield process (RESEARCH.md Pattern 2 + Pitfall 4).
        switch decision.response {
        case .close:
            completionHandler(.close)
        case .deferResponse:
            completionHandler(.defer)
        case .none:
            completionHandler(.none)
        }
    }

    private func mapActionKind(_ action: ShieldAction) -> ShieldActionHandler.ActionKind {
        switch action {
        case .primaryButtonPressed:   return .primary
        case .secondaryButtonPressed: return .secondary
        @unknown default:             return .unknown
        }
    }

}
