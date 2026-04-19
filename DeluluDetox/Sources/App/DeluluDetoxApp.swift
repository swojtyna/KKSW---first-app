import SwiftUI

@main
struct DeluluDetoxApp: App {
    init() {
        let container = DIContainer.shared
        // Kolejność: feature-ownerzy najpierw. Onboarding owns ScreenTimeAuth* (D-17, Phase 01.1),
        // AppSelection owns Blocklist + TokenRecord (Phase 02). Home/Denial/Root consume
        // cross-feature UseCases registered above.
        OnboardingInjection.register(in: container)
        AppSelectionInjection.register(in: container)
        DenialInjection.register(in: container)
        HomeInjection.register(in: container)
        RootInjection.register(in: container)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(model: AppRootViewModel())
        }
    }
}
