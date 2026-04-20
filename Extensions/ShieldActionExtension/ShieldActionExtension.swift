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

        // SHL-03 shield → main-app routing is deferred to a follow-up gap-closure
        // plan (likely 04.1) that implements a local-push-notification fallback.
        //
        // Background: `ShieldActionDelegate` inherits from `NSObject` (not
        // UIViewController) and does NOT expose `extensionContext` — verified
        // against ManagedSettings.swiftinterface. The private-API workaround
        // (NSClassFromString("UIApplication") → sharedApplication → openURL:
        // via perform(_:)) is a known App Store rejection pattern (Guideline
        // 2.5.1) and is not shipped.
        //
        // For now: log the decided URL for telemetry and return .close. The
        // decision logic (ShieldActionHandler) remains fully unit-tested so
        // the fallback plan only needs to wire the dispatch mechanism.
        if let url = decision.urlToOpen {
            Self.log.info(
                "deep-link decided but dispatch deferred url=\(url.absoluteString, privacy: .public) — awaiting follow-up plan with local-push fallback"
            )
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
