import SwiftUI
import SwiftUINavigation

struct AppRootView: View {
    @Bindable var model: AppRootViewModel
    @Environment(\.scenePhase) private var scenePhase

    // Child-owned VMs per D-03 (Wzorzec B per D-24).
    // VMs rezolwują UC przez @LazyInjected → DIContainer.shared → Injection files bootstrapped
    // in DeluluDetoxApp.init().
    @State private var onboardingModel = OnboardingViewModel()
    @State private var notificationsOnboardingModel = OnboardingNotificationsViewModel()
    @State private var denialModel = DenialViewModel()
    @State private var homeModel = HomeViewModel()

    var body: some View {
        Group {
            switch model.destination {
            case .onboarding:
                OnboardingView(model: onboardingModel)
            case .notificationsOnboarding:
                OnboardingNotificationsView(model: notificationsOnboardingModel)
            case .denial:
                DenialView(model: denialModel)
            case .home:
                NavigationStack {
                    HomeView(model: homeModel)
                }
            case .none:
                // Przed pierwszą emisją statusu z repo — marka zamiast pustego tła.
                SplashView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.destination)
        .onOpenURL { url in
            // SHL-04: deliver shield-originated URLs to HomeViewModel.
            // CONTEXT §D-09: AppRootView holds homeModel as @State — calling
            // handleDeepLink directly is acceptable View-level wiring per
            // navigation GUIDE.md (no need for a Repository/PassthroughSubject
            // bridge — this is a UI affordance, not a domain concern).
            Task { @MainActor in
                await homeModel.handleDeepLink(url)
            }
        }
        .onReceive(model.deepLinkPublisher) { url in
            // SHL-03 fallback — local-notification banner tap. The delegate
            // lands URLs on AppRootViewModel.deepLinkSubject; we bridge into
            // the same HomeViewModel.handleDeepLink the .onOpenURL path uses
            // so the URL contract (deluludetox://session/active, deluludetox://)
            // has one router. Wzorzec B per navigation GUIDE.md.
            Task { @MainActor in
                await homeModel.handleDeepLink(url)
            }
        }
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
