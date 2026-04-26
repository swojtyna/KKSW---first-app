import Foundation
import UserNotifications
import Testing
@testable import DeluluDetox

@Suite("ReconcileScheduleNotificationsUseCase")
@MainActor
struct ReconcileScheduleNotificationsUseCaseTests {

    let repo: MockLocalNotificationRepository
    let captions: NotificationCaptionLibrary
    let sut: ReconcileScheduleNotificationsUseCaseImpl

    init() {
        repo = MockLocalNotificationRepository()
        captions = NotificationCaptionLibrary()
        sut = ReconcileScheduleNotificationsUseCaseImpl(repository: repo, captions: captions)
    }

    // MARK: - Tests

    @Test("Mon–Fri enabled schedule creates five weekday requests")
    func enabledMonToFri_createsFiveWeekdayRequests() async throws {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()
        let sch = makeSchedule(id: id, daysOfWeek: [2, 3, 4, 5, 6], startHour: 9, startMinute: 0, endHour: 17)

        await sut(schedule: sch)

        #expect(repo.addedRequests.count == 5)
        let ids = repo.addedRequests.map(\.identifier).sorted()
        let expectedFull = [2, 3, 4, 5, 6].map { "schedule.start.\(id.uuidString).\($0)" }.sorted()
        #expect(ids == expectedFull)
        for req in repo.addedRequests {
            let trigger = try #require(req.trigger as? UNCalendarNotificationTrigger)
            #expect(trigger.repeats)
            #expect(trigger.dateComponents.hour == 9)
            #expect(trigger.dateComponents.minute == 0)
        }
    }

    @Test("explicit calendar and timezone on date components")
    func explicitCalendarAndTimeZone_onDateComponents() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sch = makeSchedule(daysOfWeek: [2])

        await sut(schedule: sch)

        let req = try #require(repo.addedRequests.first)
        let trigger = try #require(req.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.calendar?.identifier == .gregorian)
        #expect(trigger.dateComponents.timeZone == TimeZone.current)
    }

    @Test("removes stale first, before add")
    func removesStaleFirst_beforeAdd() async {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()
        let content = UNMutableNotificationContent()
        content.body = "x"
        repo.stubPending = [
            UNNotificationRequest(identifier: "schedule.start.\(id.uuidString).7", content: content, trigger: nil),
            UNNotificationRequest(identifier: "schedule.start.OTHER.3", content: content, trigger: nil)
        ]

        await sut(schedule: makeSchedule(id: id, daysOfWeek: [2, 3]))

        #expect(repo.removedPrefixes.contains("schedule.start.\(id.uuidString)."))
        #expect(repo.stubPending.contains(where: { $0.identifier == "schedule.start.OTHER.3" }))
    }

    @Test("disabled schedule removes all pending and adds nothing")
    func disabled_removesAllPendingForId_addsNothing() async {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()

        await sut(schedule: makeSchedule(id: id, daysOfWeek: [2, 3, 4], enabled: false))

        #expect(repo.addedRequests.isEmpty)
        #expect(repo.removedPrefixes == ["schedule.start.\(id.uuidString)."])
    }

    @Test("not authorized removes stale but does NOT add")
    func notAuthorized_removesStaleButDoesNotAdd() async {
        repo.stubAuthorizationStatus = .denied
        let id = UUID()

        await sut(schedule: makeSchedule(id: id, daysOfWeek: [2, 3]))

        #expect(repo.addedRequests.isEmpty)
        #expect(repo.removedPrefixes == ["schedule.start.\(id.uuidString)."])
    }

    @Test("cross-midnight schedule schedules only evening segment")
    func crossMidnight_schedulesOnlyEveningSegment() async throws {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()
        let sch = makeSchedule(id: id, daysOfWeek: [2, 3], startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
        #expect(sch.crossesMidnight, "fixture sanity")

        await sut(schedule: sch)

        #expect(repo.addedRequests.count == 2, "two weekdays x one segment (evening only)")
        for req in repo.addedRequests {
            let trigger = try #require(req.trigger as? UNCalendarNotificationTrigger)
            #expect(trigger.dateComponents.hour == 22, "MUST be evening start, not morning segment")
            #expect(trigger.dateComponents.minute == 0)
            #expect(trigger.dateComponents.hour != 6, "morning segment MUST be skipped per D-18")
        }
    }

    @Test("single-day with endHour > startHour creates one request per weekday")
    func singleDay_endHourGreaterThanStartHour_createsOneRequestPerWeekday() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sch = makeSchedule(daysOfWeek: [6], startHour: 9, startMinute: 0, endHour: 17)

        await sut(schedule: sch)

        #expect(repo.addedRequests.count == 1)
        let trigger = try #require(repo.addedRequests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.weekday == 6)
        #expect(trigger.dateComponents.hour == 9)
    }

    @Test("caption uses caption library (not raw template)")
    func caption_usesCaptionLibrary() async throws {
        repo.stubAuthorizationStatus = .authorized

        await sut(schedule: makeSchedule(daysOfWeek: [2]))

        let body = try #require(repo.addedRequests.first?.content.body)
        #expect(!body.contains("%d"), "body must be a formatted caption, not raw template")
        #expect(captions.scheduleStartCaptions.contains(body), "body must be one of the library captions")
    }

    @Test("content carries scheduleId and kind in userInfo")
    func content_carriesScheduleIdAndKindInUserInfo() async throws {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()

        await sut(schedule: makeSchedule(id: id, daysOfWeek: [2]))

        let userInfo = try #require(repo.addedRequests.first?.content.userInfo)
        #expect(userInfo["kind"] as? String == "schedule-start")
        #expect(userInfo["scheduleId"] as? String == id.uuidString)
    }

    @Test("empty daysOfWeek adds nothing (defensive)")
    func emptyDaysOfWeek_addsNothing() async {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()

        await sut(schedule: makeSchedule(id: id, daysOfWeek: [], enabled: true))

        #expect(repo.addedRequests.isEmpty)
        #expect(repo.removedPrefixes == ["schedule.start.\(id.uuidString)."])
    }
}

// MARK: - Private Helpers

private extension ReconcileScheduleNotificationsUseCaseTests {
    func makeSchedule(
        id: UUID = UUID(),
        daysOfWeek: [Int],
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        enabled: Bool = true
    ) -> Schedule {
        Schedule(
            id: id,
            name: nil,
            daysOfWeek: daysOfWeek,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            enabled: enabled,
            blocklistId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            appVersion: "test"
        )
    }
}
