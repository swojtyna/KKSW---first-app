import Foundation
import UserNotifications
import Testing
@testable import DeluluDetox

@Suite("LocalNotificationRepository")
struct LocalNotificationRepositoryTests {

    // MARK: - NotificationCaptionLibrary

    @Test("sessionEndCopy rotates by hash, deterministic")
    func sessionEndCopy_rotatesByHash_deterministic() {
        let lib = NotificationCaptionLibrary()
        let a = lib.sessionEndCopy(for: 0, durationMinutes: 30)
        let b = lib.sessionEndCopy(for: 1, durationMinutes: 30)
        let c = lib.sessionEndCopy(for: 2, durationMinutes: 30)
        let aAgain = lib.sessionEndCopy(for: 0, durationMinutes: 30)

        #expect(a == aAgain, "same hash must yield same caption")
        #expect(Set([a, b, c]).count == 3, "3 distinct hashes must yield 3 distinct captions")
    }

    @Test("sessionEndCopy with duration interpolates minutes")
    func sessionEndCopy_withDuration_interpolatesMinutes() {
        let lib = NotificationCaptionLibrary()
        let copy = lib.sessionEndCopy(for: 0, durationMinutes: 45)
        #expect(copy.contains("45"), "expected '45' in `\(copy)`")
    }

    @Test("scheduleStartCopy rotates by hash")
    func scheduleStartCopy_rotatesByHash() {
        let lib = NotificationCaptionLibrary()
        let a = lib.scheduleStartCopy(for: 0)
        let b = lib.scheduleStartCopy(for: 1)
        #expect(a != b)
    }

    @Test("brokenStreakCopy interpolates longestStreak")
    func brokenStreakCopy_interpolatesLongestStreak() {
        let lib = NotificationCaptionLibrary()
        let copy = lib.brokenStreakCopy(longestStreak: 12, hash: 0)
        #expect(copy.contains("12"), "expected '12' in `\(copy)`")
    }

    // MARK: - MockLocalNotificationRepository contract

    @Test("removeByPrefix filters by hasPrefix")
    func removeByPrefix_filtersByHasPrefix() async {
        let mock = MockLocalNotificationRepository()
        let content = UNMutableNotificationContent()
        content.body = "x"
        mock.stubPending = [
            UNNotificationRequest(identifier: "schedule.start.ABC.2", content: content, trigger: nil),
            UNNotificationRequest(identifier: "schedule.start.ABC.3", content: content, trigger: nil),
            UNNotificationRequest(identifier: "session.end.ZZZ", content: content, trigger: nil)
        ]

        await mock.removePendingNotificationRequests(withIdentifierPrefix: "schedule.start.ABC.")

        #expect(mock.removedPrefixes == ["schedule.start.ABC."])
        #expect(mock.stubPending.map(\.identifier) == ["session.end.ZZZ"])
    }

    @Test("authorizationStatus returns stub value")
    func authorizationStatus_returnsStubValue() async {
        let mock = MockLocalNotificationRepository()
        mock.stubAuthorizationStatus = .denied
        let status = await mock.authorizationStatus()
        #expect(status == .denied)
        #expect(mock.authorizationStatusCallCount == 1)
    }

    @Test("removeByIdentifiers captures call")
    func removeByIdentifiers_capturesCall() {
        let mock = MockLocalNotificationRepository()
        let content = UNMutableNotificationContent()
        content.body = "x"
        mock.stubPending = [
            UNNotificationRequest(identifier: "a", content: content, trigger: nil),
            UNNotificationRequest(identifier: "b", content: content, trigger: nil)
        ]

        mock.removePendingNotificationRequests(withIdentifiers: ["a"])

        #expect(mock.removedIdentifierSets == [["a"]])
        #expect(mock.stubPending.map(\.identifier) == ["b"])
    }

    @Test("add captures request")
    func add_capturesRequest() async throws {
        let mock = MockLocalNotificationRepository()
        let content = UNMutableNotificationContent()
        content.body = "hello"
        let req = UNNotificationRequest(identifier: "session.end.X", content: content, trigger: nil)

        try await mock.add(req)

        #expect(mock.addedRequests.map(\.identifier) == ["session.end.X"])
    }

    @Test("requestAuthorization forwards options and returns stub")
    func requestAuthorization_forwardsOptionsAndReturnsStub() async throws {
        let mock = MockLocalNotificationRepository()
        mock.stubRequestAuthorizationResult = .success(false)

        let granted = try await mock.requestAuthorization(options: [.alert, .sound])

        #expect(!granted)
        #expect(mock.requestAuthorizationCallCount == 1)
        #expect(mock.requestedAuthorizationOptions == [[.alert, .sound]])
    }

    // MARK: - Live repository smoke

    @Test("live repository instantiates and reads auth status")
    func liveLocalNotificationRepository_instantiatesAndReadsAuthStatus() async {
        let repo = LiveLocalNotificationRepository()
        let status = await repo.authorizationStatus()
        let validCases: Set<UNAuthorizationStatus> = [.notDetermined, .denied, .authorized, .provisional, .ephemeral]
        #expect(validCases.contains(status), "unexpected status \(status.rawValue)")
    }
}
