import SwiftUI
import UserNotifications

@main
struct DeluluDetoxApp: App {
    @State private var rootModel: AppRootViewModel
    private let notificationDelegate: AppNotificationDelegate

    init() {
        let container = DIContainer.shared
        // Notifications first — shared facade consumed by Session / Scheduling
        // / Stats via @LazyInjected / init-injected UCs.
        NotificationsInjection.register(in: container)
        // Feature-ownerzy w kolejności DI dep chains.
        // Onboarding owns ScreenTimeAuth* (D-17, Phase 01.1).
        // AppSelection owns Blocklist + TokenRecord (Phase 02).
        // Session owns SessionRecord + SessionEnforcer + Session UCs (Phase 03).
        // Home/Denial/Root consume cross-feature UseCases registered above.
        OnboardingInjection.register(in: container)
        AppSelectionInjection.register(in: container)
        SessionInjection.register(in: container)
        SchedulingInjection.register(in: container)
        // Stats (Plan 06-05) — MUST register AFTER SessionInjection because
        // ObserveStatsUseCase resolves ObserveSessionHistoryUseCase from the container.
        StatsInjection.register(in: container)
        DenialInjection.register(in: container)
        HomeInjection.register(in: container)
        RootInjection.register(in: container)

        // Phase 6: composite notification delegate replaces the Phase 4
        // shield-only deep-link delegate. Dispatches by identifier prefix:
        //   shield-deeplink.* → SHL-03 deep-link (handler below, byte-identical
        //                        to the Phase 4 closure)
        //   session.end.*    → NTF-01 (silent in foreground)
        //   schedule.start.* → NTF-02 (banner + sound)
        let model = AppRootViewModel()
        self._rootModel = State(wrappedValue: model)
        self.notificationDelegate = AppNotificationDelegate { [weak model] url in
            await MainActor.run { model?.ingestShieldDeepLink(url) }
        }
        UNUserNotificationCenter.current().delegate = self.notificationDelegate

        // SHL-03 regression hotfix: the shield extension posts a local notification
        // on primary-button tap, and iOS silently drops it when authorization is
        // .notDetermined. The D-13 lazy prompt (SchedulePermissionPromptUseCase)
        // only fires after the first `.completed` session — too late for users
        // who hit a shield before completing any session. Restoring the launch
        // prompt here until onboarding gains a dedicated notification-auth step.
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
