import Foundation
import ManagedSettingsUI
import UIKit

/// Pure builder for the branded `ShieldConfiguration`. Extracted from the
/// extension class so XCTest can drive it without spinning up an extension
/// process. The extension calls `ShieldConfigurationBuilder().make(...)`
/// from each of its four `configuration(shielding:)` overrides (D-14).
struct ShieldConfigurationBuilder {

    // MARK: Brand palette — matches Phase 1 violet #7C3AED (no asset catalog).
    private let violetSolid = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1.0)
    private let violetTint  = UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 0.75)

    /// Build a branded `ShieldConfiguration`. If `remainingMinutes` is `nil`
    /// (i.e., the extension could not read `active_session.json`) the
    /// fallback copy renders instead — same brand, generic Polish text (D-12, D-13).
    func make(remainingMinutes: Int?) -> ShieldConfiguration {
        let icon = UIImage(
            systemName: "hand.raised.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold)
        )?.withTintColor(.white, renderingMode: .alwaysOriginal)

        let title: String
        let subtitle: String
        let primaryLabel: String

        if let minutes = remainingMinutes {
            // SHL-01 active-session branch (D-03, D-04, D-05).
            title = "Serio?"
            subtitle = "Jeszcze \(minutes) min zanim znowu będziesz mógł scrollować."
            primaryLabel = "Zobacz ile zostało"
        } else {
            // SHL-02 fallback branch (D-12, D-13).
            title = "Zablokowane"
            subtitle = "Zamknij i zrób coś mądrzejszego."
            primaryLabel = "Otwórz DeluluDetox"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: violetTint,
            icon: icon,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor.white.withAlphaComponent(0.88)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: primaryLabel, color: .white),
            primaryButtonBackgroundColor: violetSolid,
            // Explicit "Zamknij" per Claude's Discretion default in CONTEXT §D-05 last bullet.
            // Apple system blue keeps it visually distinct from the violet primary.
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Zamknij", color: .systemBlue)
        )
    }
}
