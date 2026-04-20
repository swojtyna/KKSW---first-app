import SwiftUI
import UserNotifications

@main
struct DeluluDetoxApp: App {
    @State private var rootModel: AppRootViewModel
    private let notificationDelegate: ShieldDeepLinkNotificationDelegate

    init() {
        let container = DIContainer.shared
        // Kolejność: feature-ownerzy najpierw.
        // Onboarding owns ScreenTimeAuth* (D-17, Phase 01.1).
        // AppSelection owns Blocklist + TokenRecord (Phase 02).
        // Session owns SessionRecord + SessionEnforcer + Session UCs (Phase 03).
        // Home/Denial/Root consume cross-feature UseCases registered above.
        OnboardingInjection.register(in: container)
        AppSelectionInjection.register(in: container)
        SessionInjection.register(in: container)
        SchedulingInjection.register(in: container)
        DenialInjection.register(in: container)
        HomeInjection.register(in: container)
        RootInjection.register(in: container)

        // SHL-03 fallback: notification delegate (main thread at app launch).
        // Capture rootModel weakly via a holder so the delegate does NOT retain
        // the VM; rootModel owns the publisher the View subscribes to.
        let model = AppRootViewModel()
        self._rootModel = State(wrappedValue: model)
        self.notificationDelegate = ShieldDeepLinkNotificationDelegate { [weak model] url in
            await MainActor.run { model?.ingestShieldDeepLink(url) }
        }
        UNUserNotificationCenter.current().delegate = self.notificationDelegate

        // Lazy authorization — only prompt on .notDetermined. Denial is
        // acceptable: the shield still logs the decided URL (telemetry) and
        // the primary button still dismisses cleanly. A denied user simply
        // loses the banner affordance; we never re-prompt silently.
        Task.detached {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .badge])
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(model: rootModel)
        }
    }
}
