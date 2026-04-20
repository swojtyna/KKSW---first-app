import XCTest
import UserNotifications
@testable import DeluluDetox

/// NTF-02 reconcile UC tests (Plan 06-04 Task 1).
/// Covers full-replace semantics, cross-midnight evening-only, explicit
/// calendar + TZ (RESEARCH Pitfall 7), auth gating, empty-days defensive
/// cleanup, caption-library sourcing, and userInfo contract.
@MainActor
final class ReconcileScheduleNotificationsUseCaseTests: XCTestCase {

    private var repo: MockLocalNotificationRepository!
    private var captions: NotificationCaptionLibrary!
    private var sut: ReconcileScheduleNotificationsUseCaseImpl!

    override func setUp() async throws {
        try await super.setUp()
        repo = MockLocalNotificationRepository()
        captions = NotificationCaptionLibrary()
        sut = ReconcileScheduleNotificationsUseCaseImpl(repository: repo, captions: captions)
    }

    override func tearDown() async throws {
        sut = nil
        captions = nil
        repo = nil
        try await super.tearDown()
    }

    // MARK: - Fixture

    private func schedule(
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

    // MARK: - Tests

    func testEnabledMonToFri_createsFiveWeekdayRequests() async throws {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()
        let sch = schedule(id: id, daysOfWeek: [2, 3, 4, 5, 6], startHour: 9, startMinute: 0, endHour: 17)

        await sut(schedule: sch)

        XCTAssertEqual(repo.addedRequests.count, 5)
        let ids = repo.addedRequests.map(\.identifier).sorted()
        let expected = [2, 3, 4, 5, 6].map { "schedule.start.\(id.uuidString).\($0)" }.sorted()
        XCTAssertEqual(ids, expected)
        for req in repo.addedRequests {
            let trigger = try XCTUnwrap(req.trigger as? UNCalendarNotificationTrigger)
            XCTAssertTrue(trigger.repeats)
            XCTAssertEqual(trigger.dateComponents.hour, 9)
            XCTAssertEqual(trigger.dateComponents.minute, 0)
        }
    }

    func testExplicitCalendarAndTimeZone_onDateComponents() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sch = schedule(daysOfWeek: [2])

        await sut(schedule: sch)

        let req = try XCTUnwrap(repo.addedRequests.first)
        let trigger = try XCTUnwrap(req.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.calendar?.identifier, .gregorian)
        XCTAssertEqual(trigger.dateComponents.timeZone, TimeZone.current)
    }

    func testRemovesStaleFirst_beforeAdd() async {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()
        let content = UNMutableNotificationContent()
        content.body = "x"
        repo.stubPending = [
            UNNotificationRequest(identifier: "schedule.start.\(id.uuidString).7", content: content, trigger: nil),
            UNNotificationRequest(identifier: "schedule.start.OTHER.3", content: content, trigger: nil)
        ]

        await sut(schedule: schedule(id: id, daysOfWeek: [2, 3]))

        XCTAssertTrue(repo.removedPrefixes.contains("schedule.start.\(id.uuidString)."))
        XCTAssertTrue(repo.stubPending.contains(where: { $0.identifier == "schedule.start.OTHER.3" }))
    }

    func testDisabled_removesAllPendingForId_addsNothing() async {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()

        await sut(schedule: schedule(id: id, daysOfWeek: [2, 3, 4], enabled: false))

        XCTAssertTrue(repo.addedRequests.isEmpty)
        XCTAssertEqual(repo.removedPrefixes, ["schedule.start.\(id.uuidString)."])
    }

    func testNotAuthorized_removesStaleButDoesNotAdd() async {
        repo.stubAuthorizationStatus = .denied
        let id = UUID()

        await sut(schedule: schedule(id: id, daysOfWeek: [2, 3]))

        XCTAssertTrue(repo.addedRequests.isEmpty)
        XCTAssertEqual(repo.removedPrefixes, ["schedule.start.\(id.uuidString)."])
    }

    func testCrossMidnight_schedulesOnlyEveningSegment() async throws {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()
        // 22:00 -> 06:00 — crossesMidnight because (6,0) <= (22,0).
        let sch = schedule(id: id, daysOfWeek: [2, 3], startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)
        XCTAssertTrue(sch.crossesMidnight, "fixture sanity")

        await sut(schedule: sch)

        XCTAssertEqual(repo.addedRequests.count, 2, "two weekdays x one segment (evening only)")
        for req in repo.addedRequests {
            let trigger = try XCTUnwrap(req.trigger as? UNCalendarNotificationTrigger)
            XCTAssertEqual(trigger.dateComponents.hour, 22, "MUST be evening start, not morning segment")
            XCTAssertEqual(trigger.dateComponents.minute, 0)
            XCTAssertNotEqual(trigger.dateComponents.hour, 6, "morning segment MUST be skipped per D-18")
        }
    }

    func testSingleDay_endHourGreaterThanStartHour_createsOneRequestPerWeekday() async throws {
        repo.stubAuthorizationStatus = .authorized
        let sch = schedule(daysOfWeek: [6], startHour: 9, startMinute: 0, endHour: 17)

        await sut(schedule: sch)

        XCTAssertEqual(repo.addedRequests.count, 1)
        let trigger = try XCTUnwrap(repo.addedRequests.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.weekday, 6)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
    }

    func testCaption_usesCaptionLibrary() async throws {
        repo.stubAuthorizationStatus = .authorized

        await sut(schedule: schedule(daysOfWeek: [2]))

        let body = try XCTUnwrap(repo.addedRequests.first?.content.body)
        XCTAssertFalse(body.contains("%d"), "body must be a formatted caption, not raw template")
        XCTAssertTrue(captions.scheduleStartCaptions.contains(body), "body must be one of the library captions")
    }

    func testContent_carriesScheduleIdAndKindInUserInfo() async throws {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()

        await sut(schedule: schedule(id: id, daysOfWeek: [2]))

        let userInfo = try XCTUnwrap(repo.addedRequests.first?.content.userInfo)
        XCTAssertEqual(userInfo["kind"] as? String, "schedule-start")
        XCTAssertEqual(userInfo["scheduleId"] as? String, id.uuidString)
    }

    func testEmptyDaysOfWeek_addsNothing() async {
        repo.stubAuthorizationStatus = .authorized
        let id = UUID()

        await sut(schedule: schedule(id: id, daysOfWeek: [], enabled: true))

        XCTAssertTrue(repo.addedRequests.isEmpty)
        // Stale still removed (defensive).
        XCTAssertEqual(repo.removedPrefixes, ["schedule.start.\(id.uuidString)."])
    }
}
