import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit
import os

/// SHL-01 (branded shield) + SHL-02 (fallback for unknown/expired tokens).
/// All four overrides delegate to `buildShieldConfiguration()` per CONTEXT §D-14.
/// Read-only against App Group files (D-16). Imports limited to Foundation
/// + UIKit + ManagedSettings + ManagedSettingsUI + os to respect 6 MB
/// extension RAM ceiling (D-17, PROJECT.md Hard Constraint §8).
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox.ShieldConfigurationExtension",
        category: "ShieldConfig"
    )

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        buildShieldConfiguration()
    }

    // MARK: - Private

    private func buildShieldConfiguration() -> ShieldConfiguration {
        let remainingMinutes = ActiveSessionEnvelopeReader.loadRemainingMinutes()
        // Scalar-only `.public` log — no PII (booleans + ints only).
        Self.log.info(
            "build remainingMinutes=\(remainingMinutes ?? -1, privacy: .public) fallback=\(remainingMinutes == nil, privacy: .public)"
        )
        return ShieldConfigurationBuilder().make(remainingMinutes: remainingMinutes)
    }
}
