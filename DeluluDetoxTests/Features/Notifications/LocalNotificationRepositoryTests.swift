import XCTest
import UserNotifications
@testable import DeluluDetox

final class LocalNotificationRepositoryTests: XCTestCase {

    // MARK: - NotificationCaptionLibrary

    func testSessionEndCopy_rotatesByHash_deterministic() {
        let lib = NotificationCaptionLibrary()
        let a = lib.sessionEndCopy(for: 0, durationMinutes: 30)
        let b = lib.sessionEndCopy(for: 1, durationMinutes: 30)
        let c = lib.sessionEndCopy(for: 2, durationMinutes: 30)
        let aAgain = lib.sessionEndCopy(for: 0, durationMinutes: 30)

        XCTAssertEqual(a, aAgain, "same hash must yield same caption")
        XCTAssertEqual(Set([a, b, c]).count, 3, "3 distinct hashes must yield 3 distinct captions")
    }

    func testSessionEndCopy_withDuration_interpolatesMinutes() {
        let lib = NotificationCaptionLibrary()
        // Index 0 template contains %d.
        let copy = lib.sessionEndCopy(for: 0, durationMinutes: 45)
        XCTAssertTrue(copy.contains("45"), "expected '45' in `\(copy)`")
    }

    func testScheduleStartCopy_rotatesByHash() {
        let lib = NotificationCaptionLibrary()
        let a = lib.scheduleStartCopy(for: 0)
        let b = lib.scheduleStartCopy(for: 1)
        XCTAssertNotEqual(a, b)
    }

    func testBrokenStreakCopy_interpolatesLongestStreak() {
        let lib = NotificationCaptionLibrary()
        let copy = lib.brokenStreakCopy(longestStreak: 12, hash: 0)
        XCTAssertTrue(copy.contains("12"), "expected '12' in `\(copy)`")
    }

    // MARK: - MockLocalNotificationRepository contract

    func testRemoveByPrefix_filtersByHasPrefix() async {
        let mock = MockLocalNotificationRepository()
        let content = UNMutableNotificationContent()
        content.body = "x"
        mock.stubPending = [
            UNNotificationRequest(identifier: "schedule.start.ABC.2", content: content, trigger: nil),
            UNNotificationRequest(identifier: "schedule.start.ABC.3", content: content, trigger: nil),
            UNNotificationRequest(identifier: "session.end.ZZZ", content: content, trigger: nil)
        ]

        await mock.removePendingNotificationRequests(withIdentifierPrefix: "schedule.start.ABC.")

        XCTAssertEqual(mock.removedPrefixes, ["schedule.start.ABC."])
        XCTAssertEqual(mock.stubPending.map(\.identifier), ["session.end.ZZZ"])
    }

    func testAuthorizationStatus_returnsStubValue() async {
        let mock = MockLocalNotificationRepository()
        mock.stubAuthorizationStatus = .denied
        let status = await mock.authorizationStatus()
        XCTAssertEqual(status, .denied)
        XCTAssertEqual(mock.authorizationStatusCallCount, 1)
    }

    func testRemoveByIdentifiers_capturesCall() {
        let mock = MockLocalNotificationRepository()
        let content = UNMutableNotificationContent()
        content.body = "x"
        mock.stubPending = [
            UNNotificationRequest(identifier: "a", content: content, trigger: nil),
            UNNotificationRequest(identifier: "b", content: content, trigger: nil)
        ]

        mock.removePendingNotificationRequests(withIdentifiers: ["a"])

        XCTAssertEqual(mock.removedIdentifierSets, [["a"]])
        XCTAssertEqual(mock.stubPending.map(\.identifier), ["b"])
    }

    func testAdd_capturesRequest() async throws {
        let mock = MockLocalNotificationRepository()
        let content = UNMutableNotificationContent()
        content.body = "hello"
        let req = UNNotificationRequest(identifier: "session.end.X", content: content, trigger: nil)

        try await mock.add(req)

        XCTAssertEqual(mock.addedRequests.map(\.identifier), ["session.end.X"])
    }

    func testRequestAuthorization_forwardsOptionsAndReturnsStub() async throws {
        let mock = MockLocalNotificationRepository()
        mock.stubRequestAuthorizationResult = .success(false)

        let granted = try await mock.requestAuthorization(options: [.alert, .sound])

        XCTAssertFalse(granted)
        XCTAssertEqual(mock.requestAuthorizationCallCount, 1)
        XCTAssertEqual(mock.requestedAuthorizationOptions, [[.alert, .sound]])
    }

    // MARK: - Live repository smoke (construction + identifier consistency)

    func testLiveLocalNotificationRepository_instantiatesAndReadsAuthStatus() async {
        // Integration smoke: the live repository must construct and return
        // *some* authorization status from the test simulator environment.
        // We don't assert a specific value — simulator defaults vary.
        let repo = LiveLocalNotificationRepository()
        let status = await repo.authorizationStatus()
        // Just assert the returned enum is a known case (no crash, no nil).
        let validCases: Set<UNAuthorizationStatus> = [.notDetermined, .denied, .authorized, .provisional, .ephemeral]
        XCTAssertTrue(validCases.contains(status), "unexpected status \(status.rawValue)")
    }
}
