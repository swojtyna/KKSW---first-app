import Foundation
import ManagedSettings
import os

/// SHL-03 — shield action handler. All overrides delegate to
/// `handle(action:completionHandler:)` per CONTEXT §D-15. Pure decision
/// logic lives in `ShieldActionHandler` (main-app target, source-shared
/// via project.yml) so it can be XCTest-unit-tested.
///
/// Read-only against App Group files (D-16). Imports limited to
/// Foundation + ManagedSettings + os to respect the 6 MB extension RAM
/// ceiling (D-17, PROJECT.md Hard Constraint §8).
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

        // Open URL if decision included one (primary action only).
        // RESEARCH.md Pattern 2: extensionContext?.open is community-confirmed
        // (Opal, one-sec, AppLocker) but unsupported per Apple DTS.
        // NOTE: `ShieldActionDelegate` inherits directly from `NSObject` and
        // does NOT expose an `extensionContext` property on iOS 26 (verified
        // via ManagedSettings.swiftinterface). Community workaround is the
        // Objective-C runtime selector trick below — resolve UIApplication at
        // runtime, look up `shared`, then `open:options:completionHandler:`.
        // This bypasses the extension `UIApplication.shared` import ban.
        if let url = decision.urlToOpen {
            Self.log.info("opening url=\(url.absoluteString, privacy: .public)")
            // TODO(SHL-03 fallback): Wave 0 spike waived — extensionContext?.open(_:)
            // is unverified on iOS 26 device from ShieldActionDelegate. Replace this
            // call with a local push notification + tap-handler that opens the app
            // when device verification (Plan 04-05) confirms the open path fails.
            #warning("SHL-03 spike waived — extensionContext.open path is best-effort; follow-up plan needed for local-push fallback")
            openURLFromExtension(url)
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

    /// Fire-and-forget URL open from a Shield extension. Uses Objective-C
    /// runtime dispatch to reach `UIApplication.shared.open(_:options:completionHandler:)`
    /// without importing UIKit's application APIs (extensions can't use
    /// `UIApplication.shared` directly — compile-time guard). Community
    /// pattern from Opal / one-sec / AppLocker.
    ///
    /// Return value intentionally ignored — `completionHandler(.close)` below
    /// fires unconditionally so the shield process is released even if the
    /// open selector silently no-ops (Pitfall 4).
    private func openURLFromExtension(_ url: URL) {
        let uiApplicationClass: AnyClass? = NSClassFromString("UIApplication")
        guard let appClass = uiApplicationClass else {
            Self.log.error("UIApplication class not found via runtime")
            return
        }
        let sharedSelector = NSSelectorFromString("sharedApplication")
        guard appClass.responds(to: sharedSelector),
              let sharedApp = (appClass as AnyObject).perform(sharedSelector)?.takeUnretainedValue()
        else {
            Self.log.error("sharedApplication unavailable from extension")
            return
        }
        let openSelector = NSSelectorFromString("openURL:")
        guard (sharedApp as AnyObject).responds(to: openSelector) else {
            Self.log.error("openURL: selector unavailable")
            return
        }
        _ = (sharedApp as AnyObject).perform(openSelector, with: url)
        Self.log.info("openURL: dispatched via runtime")
    }
}
