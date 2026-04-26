import Observation

@MainActor
@Observable
final class OnboardingNotificationsViewModel: @unchecked Sendable {
    private(set) var isRequesting = false

    @ObservationIgnored
    @LazyInjected private var schedulePermissionPrompt: SchedulePermissionPromptUseCase
    @ObservationIgnored
    @LazyInjected private var completeOnboarding: CompleteNotificationsOnboardingUseCase

    init() {}

    func allowTapped() async {
        isRequesting = true
        await schedulePermissionPrompt()
        isRequesting = false
        completeOnboarding()
    }

    func skipTapped() {
        completeOnboarding()
    }
}
