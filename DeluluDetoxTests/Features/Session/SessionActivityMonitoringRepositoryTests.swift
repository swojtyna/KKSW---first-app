import Foundation
import DeviceActivity
import Testing
@testable import DeluluDetox

@Suite("LiveSessionActivityMonitoringRepository")
@MainActor
struct SessionActivityMonitoringRepositoryTests {

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

    // MARK: - startActivityMonitoring

    @Test("startActivityMonitoring invokes center with quickSession name and non-repeating schedule")
    func startActivityMonitoringInvokesCenterWithQuickSessionNameAndNonRepeatingSchedule() async throws {
        let fakeCenter = FakeCenter()
        let repo = LiveSessionActivityMonitoringRepository(center: fakeCenter)
        let session = makeSession(durationSeconds: 30 * 60)

        try await repo.startActivityMonitoring(for: session)

        #expect(fakeCenter.startedActivities == [SessionActivityNames.quickSession])
        #expect(fakeCenter.startedSchedules.count == 1)
        #expect(fakeCenter.startedSchedules.first?.repeats == false)
    }

    @Test("startActivityMonitoring throws wrapped error when center throws")
    func startActivityMonitoringThrowsWrappedErrorWhenCenterThrows() async {
        let fakeCenter = FakeCenter()
        fakeCenter.startError = TestError()
        let repo = LiveSessionActivityMonitoringRepository(center: fakeCenter)

        do {
            try await repo.startActivityMonitoring(for: makeSession())
            Issue.record("expected throw")
        } catch SessionActivityMonitoringError.deviceActivityStartFailed(let inner) {
            #expect((inner as? TestError) != nil)
        } catch {
            Issue.record("wrong error type \(error)")
        }
    }

    // MARK: - stopActivityMonitoring

    @Test("stopActivityMonitoring stops the quickSession activity")
    func stopActivityMonitoringStopsTheQuickSessionActivity() async {
        let fakeCenter = FakeCenter()
        let repo = LiveSessionActivityMonitoringRepository(center: fakeCenter)
        await repo.stopActivityMonitoring()
        #expect(fakeCenter.stoppedActivities == [SessionActivityNames.quickSession])
    }

    // MARK: - SessionActivityNames constant

    @Test("SessionActivityNames rawValue matches shared constant")
    func sessionActivityNameRawValueMatchesSharedConstant() {
        #expect(SessionActivityNames.quickSession.rawValue == "deluludetox.quickSession")
    }
}

// MARK: - Private Helpers

private extension SessionActivityMonitoringRepositoryTests {
    func makeSession(startingAt: Date = Date(), durationSeconds: Int = 1800) -> SessionRecord {
        SessionRecord(
            blocklistId: UUID(),
            startedAt: startingAt,
            plannedEndAt: startingAt.addingTimeInterval(TimeInterval(durationSeconds)),
            plannedDurationSeconds: durationSeconds,
            appVersion: "test"
        )
    }
}
