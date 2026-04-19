import SwiftUI

@main
struct DeluluDetoxApp: App {
    init() {
        // TRANSITIONAL bootstrap: Onboarding first (feature-owner of ScreenTimeAuth*, D-17).
        // Home/Denial/Root Injection added in 01.1-04 when DependencyContainer is deleted
        // and AppRootView owns child VM lifecycle via @State.
        OnboardingInjection.register(in: DIContainer.shared)
    }

    private let container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView(model: container.makeAppRootViewModel())
        }
    }
}
