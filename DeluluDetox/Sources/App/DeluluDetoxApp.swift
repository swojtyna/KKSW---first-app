import SwiftUI

@main
struct DeluluDetoxApp: App {
    init() {
        let container = DIContainer.shared
        // Kolejność: Onboarding pierwszy (feature-owner ScreenTimeAuth*, D-17). Reszta no-op po nim.
        OnboardingInjection.register(in: container)
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
