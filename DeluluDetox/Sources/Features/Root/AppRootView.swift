import SwiftUI

struct AppRootView: View {
    @Bindable var model: AppRootViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.screen {
            case .onboarding(let vm):
                OnboardingView(model: vm)
            case .denial(let vm):
                DenialView(model: vm)
            case .home(let vm):
                NavigationStack {
                    HomeView(model: vm)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.screenTag)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                model.checkAuthorization()
            }
        }
    }
}

#Preview {
    AppRootView(model: AppRootViewModel(container: DependencyContainer()))
}
