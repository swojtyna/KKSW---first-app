import XCTest
import UserNotifications
@testable import DeluluDetox

@MainActor
final class SchedulePermissionPromptUseCaseTests: XCTestCase {

    func testPrompts_whenNotDetermined() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .notDetermined
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)

        await sut()

        XCTAssertEqual(repo.requestAuthorizationCallCount, 1)
        let opts = repo.requestedAuthorizationOptions.first ?? []
        XCTAssertTrue(opts.contains(.alert))
        XCTAssertTrue(opts.contains(.sound))
    }

    func testSkips_whenAuthorized() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .authorized
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)
        await sut()
        XCTAssertEqual(repo.requestAuthorizationCallCount, 0)
    }

    func testSkips_whenDenied() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .denied
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)
        await sut()
        XCTAssertEqual(repo.requestAuthorizationCallCount, 0)
    }

    func testDoesNotRequestBadge() async {
        let repo = MockLocalNotificationRepository()
        repo.stubAuthorizationStatus = .notDetermined
        let sut = SchedulePermissionPromptUseCaseImpl(repository: repo)
        await sut()
        let opts = repo.requestedAuthorizationOptions.first ?? []
        XCTAssertFalse(opts.contains(.badge), "no badge UX in MVP per RESEARCH A7")
    }
}
