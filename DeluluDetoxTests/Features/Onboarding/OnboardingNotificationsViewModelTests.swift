import Testing
@testable import DeluluDetox

@MainActor
struct OnboardingNotificationsViewModelTests {

    @Test func allowTapped_callsPermissionPromptThenCompletesOnboarding() async {
        let mockPrompt = MockSchedulePermissionPromptUseCase()
        let mockComplete = MockCompleteNotificationsOnboardingUseCase()
        DIContainer.shared.reset()
        DIContainer.shared.register(SchedulePermissionPromptUseCase.self, scope: .unique) { _ in mockPrompt }
        DIContainer.shared.register(CompleteNotificationsOnboardingUseCase.self, scope: .unique) { _ in mockComplete }

        let vm = OnboardingNotificationsViewModel()
        await vm.allowTapped()

        #expect(mockPrompt.callCount == 1)
        #expect(mockComplete.callCount == 1)
        #expect(!vm.isRequesting)
    }

    @Test func allowTapped_setsIsRequestingDuringCall() async {
        let mockPrompt = MockSchedulePermissionPromptUseCase()
        let mockComplete = MockCompleteNotificationsOnboardingUseCase()
        DIContainer.shared.reset()
        DIContainer.shared.register(SchedulePermissionPromptUseCase.self, scope: .unique) { _ in mockPrompt }
        DIContainer.shared.register(CompleteNotificationsOnboardingUseCase.self, scope: .unique) { _ in mockComplete }

        let vm = OnboardingNotificationsViewModel()
        #expect(!vm.isRequesting)

        await vm.allowTapped()

        #expect(!vm.isRequesting)
    }

    @Test func skipTapped_completesOnboardingWithoutPermissionPrompt() {
        let mockPrompt = MockSchedulePermissionPromptUseCase()
        let mockComplete = MockCompleteNotificationsOnboardingUseCase()
        DIContainer.shared.reset()
        DIContainer.shared.register(SchedulePermissionPromptUseCase.self, scope: .unique) { _ in mockPrompt }
        DIContainer.shared.register(CompleteNotificationsOnboardingUseCase.self, scope: .unique) { _ in mockComplete }

        let vm = OnboardingNotificationsViewModel()
        vm.skipTapped()

        #expect(mockPrompt.callCount == 0)
        #expect(mockComplete.callCount == 1)
    }
}
