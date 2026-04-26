import Foundation
import Testing
@testable import DeluluDetox

@Suite("SyncScheduleWithSystemUseCase")
@MainActor
struct SyncScheduleWithSystemUseCaseTests {

    @Test("sync stops old then starts new when enabled")
    func syncStopsOldThenStartsNewWhenEnabled() async throws {
        let (uc, repo, monitoring, _) = makeSUT()

        let s = makeSchedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        try await uc(schedule: s)

        #expect(monitoring.stopMonitoringCallCount == 1)
        #expect(monitoring.stoppedScheduleIds.last == s.id)
        #expect(monitoring.startMonitoringCallCount == 1)
        #expect(monitoring.lastStartedSchedule?.id == s.id)
        #expect(monitoring.callLog.first == .stop(scheduleId: s.id))
        #expect(monitoring.callLog.last == .start(scheduleId: s.id))
    }

    @Test("sync only stops when schedule is disabled")
    func syncOnlyStopsWhenScheduleDisabled() async throws {
        let (uc, repo, monitoring, _) = makeSUT()

        let s = makeSchedule(id: UUID(), enabled: false)
        repo.schedulesSubject.send([s])

        try await uc(schedule: s)

        #expect(monitoring.stopMonitoringCallCount == 1)
        #expect(monitoring.startMonitoringCallCount == 0)
    }

    @Test("rolls back schedule JSON when startMonitoring throws")
    func syncRollsBackScheduleJSONWhenStartMonitoringThrows() async {
        let (uc, repo, monitoring, _) = makeSUT()

        let id = UUID()
        let prior = makeSchedule(id: id, enabled: false)
        repo.schedulesSubject.send([prior])

        let new = makeSchedule(id: id, enabled: true)

        struct BoomError: Error {}
        monitoring.startMonitoringError = ScheduleActivityMonitoringError.startFailed(BoomError())

        do {
            try await uc(schedule: new)
            Issue.record("Expected uc(schedule:) to throw when startMonitoring throws")
        } catch {
            // Expected — rethrows.
        }

        #expect(monitoring.stopMonitoringCallCount == 1)
        #expect(monitoring.startMonitoringCallCount == 1)
        #expect(repo.upsertCallCount == 1)
        #expect(repo.lastUpserted?.id == id)
        #expect(repo.lastUpserted?.enabled == false)
    }

    @Test("does not retry stop after start failure")
    func syncDoesNotRetryStopMonitoringAfterStartFailure() async {
        let (uc, repo, monitoring, _) = makeSUT()

        let s = makeSchedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        struct BoomError: Error {}
        monitoring.startMonitoringError = ScheduleActivityMonitoringError.startFailed(BoomError())

        _ = try? await uc(schedule: s)

        #expect(monitoring.stopMonitoringCallCount == 1)
    }

    // MARK: - Notification reconcile

    @Test("reconciles notifications after startMonitoring success")
    func reconcilesNotifications_afterStartMonitoringSuccess() async throws {
        let (uc, repo, _, reconcile) = makeSUT()

        let s = makeSchedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        try await uc(schedule: s)

        #expect(reconcile.receivedSchedules.count == 1)
        #expect(reconcile.receivedSchedules.last?.id == s.id)
        #expect(reconcile.receivedSchedules.last?.enabled == true)
    }

    @Test("reconciles notifications on disabled early return")
    func reconcilesNotifications_onDisabledEarlyReturn() async throws {
        let (uc, repo, _, reconcile) = makeSUT()

        let s = makeSchedule(id: UUID(), enabled: false)
        repo.schedulesSubject.send([s])

        try await uc(schedule: s)

        #expect(reconcile.receivedSchedules.count == 1)
        #expect(reconcile.receivedSchedules.last?.id == s.id)
        #expect(reconcile.receivedSchedules.last?.enabled == false)
    }

    @Test("does NOT reconcile notifications when startMonitoring throws")
    func doesNotReconcileNotifications_whenStartMonitoringThrows() async {
        let (uc, repo, monitoring, reconcile) = makeSUT()

        let s = makeSchedule(id: UUID(), enabled: true)
        repo.schedulesSubject.send([s])

        struct BoomError: Error {}
        monitoring.startMonitoringError = ScheduleActivityMonitoringError.startFailed(BoomError())

        do {
            try await uc(schedule: s)
            Issue.record("expected throw")
        } catch {}

        #expect(reconcile.receivedSchedules.isEmpty)
    }
}

// MARK: - Private Helpers

private extension SyncScheduleWithSystemUseCaseTests {
    func makeSchedule(id: UUID, enabled: Bool) -> Schedule {
        Schedule(
            id: id,
            name: nil,
            daysOfWeek: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0,
            enabled: enabled,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }

    func makeSUT(
        repo: MockScheduleRepository = MockScheduleRepository(),
        monitoring: MockScheduleActivityMonitoringRepository = MockScheduleActivityMonitoringRepository(),
        reconcile: MockReconcileScheduleNotificationsUseCase = MockReconcileScheduleNotificationsUseCase()
    ) -> (SyncScheduleWithSystemUseCaseImpl, MockScheduleRepository, MockScheduleActivityMonitoringRepository, MockReconcileScheduleNotificationsUseCase) {
        let uc = SyncScheduleWithSystemUseCaseImpl(
            monitoring: monitoring,
            repository: repo,
            reconcileNotifications: reconcile
        )
        return (uc, repo, monitoring, reconcile)
    }
}
