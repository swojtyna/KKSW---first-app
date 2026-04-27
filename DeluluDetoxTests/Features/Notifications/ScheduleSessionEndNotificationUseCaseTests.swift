import Foundation
import UserNotifications
import Testing
@testable import DeluluDetox

@Suite("ScheduleSessionEndNotificationUseCase")
@MainActor
struct ScheduleSessionEndNotificationUseCaseTests {

    let repo: MockLocalNotificationRepository
    let captions: NotificationCaptionLibrary
    let sut: ScheduleSessionEndNotificationUseCaseImpl

    init() {
        repo = MockLocalNotificationRepository()
        captions = NotificationCaptionLibrary()
        sut = ScheduleSessionEndNotificationUseCaseImpl(repository: repo, captions: captions)
    }

    @Test("schedules request when authorized")
    func schedulesRequest_whenAuthorized() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionId = UUID()
        let plannedEndAt = Date().addingTimeInterval(1800)

        await sut.execute(sessionId: sessionId, plannedEndAt: plannedEndAt, durationMinutes: 30)

        #expect(repo.addedRequests.count == 1)
        let req = try #require(repo.addedRequests.first)
        #expect(req.identifier == "session.end.\(sessionId.uuidString)")
        let trigger = try #require(req.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let expected = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: plannedEndAt)
        #expect(trigger.dateComponents.year == expected.year)
        #expect(trigger.dateComponents.month == expected.month)
        #expect(trigger.dateComponents.day == expected.day)
        #expect(trigger.dateComponents.hour == expected.hour)
        #expect(trigger.dateComponents.minute == expected.minute)
        #expect(trigger.dateComponents.second == expected.second)
    }

    @Test("skips add when not authorized")
    func skipsAdd_whenNotAuthorized() async {
        repo.stubAuthorizationStatus = .denied
        await sut.execute(sessionId: UUID(), plannedEndAt: Date(), durationMinutes: 30)
        #expect(repo.addedRequests.isEmpty)
    }

    @Test("skips add when not determined")
    func skipsAdd_whenNotDetermined() async {
        repo.stubAuthorizationStatus = .notDetermined
        await sut.execute(sessionId: UUID(), plannedEndAt: Date(), durationMinutes: 30)
        #expect(repo.addedRequests.isEmpty)
    }

    @Test("caption interpolates durationMinutes (no raw %d template)")
    func captionInterpolation_usesDurationMinutes() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        await sut.execute(sessionId: sessionId, plannedEndAt: Date(), durationMinutes: 45)
        let body = try #require(repo.addedRequests.first?.content.body)
        #expect(!body.contains("%d"), "caption must be formatted, not raw template")
    }

    @Test("caption rotates by deterministic hash")
    func caption_rotatesByDeterministicHash() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionA = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let sessionB = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

        await sut.execute(sessionId: sessionA, plannedEndAt: Date(), durationMinutes: 30)
        await sut.execute(sessionId: sessionB, plannedEndAt: Date(), durationMinutes: 30)
        await sut.execute(sessionId: sessionA, plannedEndAt: Date(), durationMinutes: 30)

        #expect(repo.addedRequests.count == 3)
        #expect(
            repo.addedRequests[0].content.body == repo.addedRequests[2].content.body,
            "rotation must be deterministic per-sessionId across calls"
        )
    }

    @Test("userInfo carries sessionId as opaque string")
    func userInfo_carriesSessionIdAsOpaqueString() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sessionId = UUID()
        await sut.execute(sessionId: sessionId, plannedEndAt: Date(), durationMinutes: 30)
        let userInfo = try #require(repo.addedRequests.first?.content.userInfo)
        #expect(userInfo["kind"] as? String == "session-end")
        #expect(userInfo["sessionId"] as? String == sessionId.uuidString)
    }
}
