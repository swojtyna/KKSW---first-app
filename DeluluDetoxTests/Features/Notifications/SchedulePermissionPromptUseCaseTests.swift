import Foundation
import UserNotifications
import Testing
@testable import DeluluDetox

@Suite("SchedulePermissionPromptUseCase")
@MainActor
struct SchedulePermissionPromptUseCaseTests {

    @Test("prompts when authorization not determined")
    func prompts_whenNotDetermined() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .notDetermined
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)

        await sut.execute()

        #expect(repo.requestAuthorizationCallCount == 1)
        let opts = repo.requestedAuthorizationOptions.first ?? []
        #expect(opts.contains(.alert))
        #expect(opts.contains(.sound))
    }

    @Test("skips when already authorized")
    func skips_whenAuthorized() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .authorized
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)
        await sut.execute()
        #expect(repo.requestAuthorizationCallCount == 0)
    }

    @Test("skips when denied")
    func skips_whenDenied() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .denied
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)
        await sut.execute()
        #expect(repo.requestAuthorizationCallCount == 0)
    }

    @Test("does not request badge per MVP spec")
    func doesNotRequestBadge() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .notDetermined
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)
        await sut.execute()
        let opts = repo.requestedAuthorizationOptions.first ?? []
        #expect(!opts.contains(.badge), "no badge UX in MVP per RESEARCH A7")
    }
}
