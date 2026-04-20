import XCTest
import UserNotifications
@testable import DeluluDetox

@MainActor
final class ScheduleSessionEndNotificationUseCaseTests: XCTestCase {

    private var repo: MockLocalNotificationRepository!
    private var captions: NotificationCaptionLibrary!
    private var sut: ScheduleSessionEndNotificationUseCaseImpl!

    override func setUp() {
        super.setUp()
        repo = MockLocalNotificationRepository()
        captions = NotificationCaptionLibrary()
        sut = ScheduleSessionEndNotificationUseCaseImpl(repository: repo, captions: captions)
    }

    override func tearDown() {
        sut = nil
        captions = nil
        repo = nil
        super.tearDown()
    }

    func testSchedulesRequest_whenAuthorized() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionId = UUID()
        let plannedEndAt = Date().addingTimeInterval(1800)

        await sut(sessionId: sessionId, plannedEndAt: plannedEndAt, durationMinutes: 30)

        XCTAssertEqual(repo.addedRequests.count, 1)
        let req = try XCTUnwrap(repo.addedRequests.first)
        XCTAssertEqual(req.identifier, "session.end.\(sessionId.uuidString)")
        let trigger = try XCTUnwrap(req.trigger as? UNCalendarNotificationTrigger)
        XCTAssertFalse(trigger.repeats)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let expected = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: plannedEndAt)
        XCTAssertEqual(trigger.dateComponents.year, expected.year)
        XCTAssertEqual(trigger.dateComponents.month, expected.month)
        XCTAssertEqual(trigger.dateComponents.day, expected.day)
        XCTAssertEqual(trigger.dateComponents.hour, expected.hour)
        XCTAssertEqual(trigger.dateComponents.minute, expected.minute)
        XCTAssertEqual(trigger.dateComponents.second, expected.second)
    }

    func testSkipsAdd_whenNotAuthorized() async {
        repo.stubAuthorizationStatus = .denied
        await sut(sessionId: UUID(), plannedEndAt: Date(), durationMinutes: 30)
        XCTAssertTrue(repo.addedRequests.isEmpty)
    }

    func testSkipsAdd_whenNotDetermined() async {
        repo.stubAuthorizationStatus = .notDetermined
        await sut(sessionId: UUID(), plannedEndAt: Date(), durationMinutes: 30)
        XCTAssertTrue(repo.addedRequests.isEmpty)
    }

    func testCaptionInterpolation_usesDurationMinutes() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        await sut(sessionId: sessionId, plannedEndAt: Date(), durationMinutes: 45)
        let body = try XCTUnwrap(repo.addedRequests.first?.content.body)
        // The caption must be formatted — never a literal %d leak.
        XCTAssertFalse(body.contains("%d"), "caption must be formatted, not raw template")
    }

    func testCaption_rotatesByDeterministicHash() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionA = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let sessionB = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

        await sut(sessionId: sessionA, plannedEndAt: Date(), durationMinutes: 30)
        await sut(sessionId: sessionB, plannedEndAt: Date(), durationMinutes: 30)
        await sut(sessionId: sessionA, plannedEndAt: Date(), durationMinutes: 30)

        XCTAssertEqual(repo.addedRequests.count, 3)
        // Deterministic: repeating sessionA must yield identical copy.
        XCTAssertEqual(
            repo.addedRequests[0].content.body,
            repo.addedRequests[2].content.body,
            "rotation must be deterministic per-sessionId across calls"
        )
    }

    func testUserInfo_carriesSessionIdAsOpaqueString() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionId = UUID()
        await sut(sessionId: sessionId, plannedEndAt: Date(), durationMinutes: 30)
        let userInfo = try XCTUnwrap(repo.addedRequests.first?.content.userInfo)
        XCTAssertEqual(userInfo["kind"] as? String, "session-end")
        XCTAssertEqual(userInfo["sessionId"] as? String, sessionId.uuidString)
    }
}
