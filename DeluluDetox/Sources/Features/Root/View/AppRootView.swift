import SwiftUI
import SwiftUINavigation

struct AppRootView: View {
    @Bindable var model: AppRootViewModel
    @Environment(\.scenePhase) private var scenePhase

    // Child-owned VMs per D-03 (Wzorzec B per D-24).
    // VMs rezolwują UC przez @LazyInjected → DIContainer.shared → Injection files bootstrapped
    // in DeluluDetoxApp.init().
    @State private var onboardingModel = OnboardingViewModel()
    @State private var denialModel = DenialViewModel()
    @State private var homeModel = HomeViewModel()

    var body: some View {
        Group {
            switch model.destination {
            case .onboarding:
                OnboardingView(model: onboardingModel)
            case .denial:
                DenialView(model: denialModel)
            case .home:
                NavigationStack {
                    HomeView(model: homeModel)
                }
            case .none:
                // Przed pierwszą emisją statusu z repo — krótki placeholder.
                Theme.background
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.destination)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                model.refreshStatus()
            }
        }
    }
}

#Preview {
    // NOTE: Preview mutates DIContainer.shared; fine because Xcode previews
    // run in a separate process from XCTest. Do NOT enable previews in CI test runs.
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    DenialInjection.register(in: container)
    HomeInjection.register(in: container)
    RootInjection.register(in: container)
    return AppRootView(model: AppRootViewModel())
}
