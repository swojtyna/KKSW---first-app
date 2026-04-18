import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
