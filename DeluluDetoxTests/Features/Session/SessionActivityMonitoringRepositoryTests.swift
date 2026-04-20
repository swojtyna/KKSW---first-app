import XCTest
import DeviceActivity
@testable import DeluluDetox

@MainActor
final class SessionActivityMonitoringRepositoryTests: XCTestCase {

    // MARK: - Fake

    final class FakeCenter: DeviceActivityCenterRunner, @unchecked Sendable {
        var startedActivities: [DeviceActivityName] = []
        var startedSchedules: [DeviceActivitySchedule] = []
        var stoppedActivities: [DeviceActivityName] = []
        var startError: Error?

        func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
            if let startError { throw startError }
            startedActivities.append(activity)
            startedSchedules.append(schedule)
        }
        func stopMonitoring(_ activities: [DeviceActivityName]) {
            stoppedActivities.append(contentsOf: activities)
        }
    }

    struct TestError: Error, Equatable {}

    // MARK: - Helpers

    private func makeSession(startingAt: Date = Date(), durationSeconds: Int = 1800) -> SessionRecord {
        SessionRecord(
            blocklistId: UUID(),
            startedAt: startingAt,
            plannedEndAt: startingAt.addingTimeInterval(TimeInterval(durationSeconds)),
            plannedDurationSeconds: durationSeconds,
            appVersion: "test"
        )
    }

    // MARK: - startActivityMonitoring

    func testStartActivityMonitoringInvokesCenterWithQuickSessionNameAndNonRepeatingSchedule() async throws {
        let fakeCenter = FakeCenter()
        let repo = LiveSessionActivityMonitoringRepository(center: fakeCenter)
        let session = makeSession(durationSeconds: 30 * 60)

        try await repo.startActivityMonitoring(for: session)

        XCTAssertEqual(fakeCenter.startedActivities, [SessionActivityNames.quickSession])
        XCTAssertEqual(fakeCenter.startedSchedules.count, 1)
        XCTAssertEqual(fakeCenter.startedSchedules.first?.repeats, false)
    }

    func testStartActivityMonitoringThrowsWrappedErrorWhenCenterThrows() async {
        let fakeCenter = FakeCenter()
        fakeCenter.startError = TestError()
        let repo = LiveSessionActivityMonitoringRepository(center: fakeCenter)

        do {
            try await repo.startActivityMonitoring(for: makeSession())
            XCTFail("expected throw")
        } catch SessionActivityMonitoringError.deviceActivityStartFailed(let inner) {
            XCTAssertTrue((inner as? TestError) != nil)
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    // MARK: - stopActivityMonitoring

    func testStopActivityMonitoringStopsTheQuickSessionActivity() async {
        let fakeCenter = FakeCenter()
        let repo = LiveSessionActivityMonitoringRepository(center: fakeCenter)
        await repo.stopActivityMonitoring()
        XCTAssertEqual(fakeCenter.stoppedActivities, [SessionActivityNames.quickSession])
    }

    // MARK: - SessionActivityNames constant

    func testSessionActivityNameRawValueMatchesSharedConstant() {
        XCTAssertEqual(SessionActivityNames.quickSession.rawValue, "deluludetox.quickSession")
    }
}
