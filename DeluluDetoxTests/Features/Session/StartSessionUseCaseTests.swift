import Foundation
import Combine
import Testing
@testable import DeluluDetox

@Suite("StartSessionUseCase")
@MainActor
struct StartSessionUseCaseTests {

    struct TestError: Error, Equatable {}

    @Test("happy path: invokes repo, then shield, then monitoring")
    func startSessionHappyPathInvokesRepoThenShieldThenMonitoring() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()

        let blocklistId = UUID()
        let duration = SessionDuration.preset(30)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = SessionRecord(
            blocklistId: blocklistId,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        mockRepo.stubbedStartSessionResult = expected

        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        let returned = try await uc(blocklistId: blocklistId, duration: duration, now: now)

        #expect(returned == expected)
        #expect(mockRepo.startSessionCallCount == 1)
        #expect(mockRepo.startSessionLastBlocklistId == blocklistId)
        #expect(mockShield.applyShieldCallCount == 1)
        #expect(mockMonitoring.startActivityMonitoringCallCount == 1)
        #expect(mockShield.clearShieldCallCount == 0)
        #expect(mockMonitoring.stopActivityMonitoringCallCount == 0)
        #expect(mockRepo.finalizeActiveSessionCallCount == 0)
    }

    @Test("rolls back when applyShield throws")
    func startSessionRollsBackWhenApplyShieldThrows() async {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()
        mockShield.applyShieldError = TestError()

        let now = Date()
        mockRepo.stubbedStartSessionResult = SessionRecord(
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        do {
            _ = try await uc(blocklistId: UUID(), duration: SessionDuration.preset(30)!, now: now)
            Issue.record("expected throw")
        } catch {
            #expect(mockRepo.startSessionCallCount == 1)
            #expect(mockShield.applyShieldCallCount == 1)
            #expect(mockMonitoring.startActivityMonitoringCallCount == 0)
            #expect(mockShield.clearShieldCallCount == 1)
            #expect(mockMonitoring.stopActivityMonitoringCallCount == 1)
            #expect(mockRepo.finalizeActiveSessionCallCount == 1)
            #expect(mockRepo.finalizeActiveSessionLastOutcome == .cancelledByUser)
            #expect(error is TestError)
        }
    }

    @Test("rolls back when startMonitoring throws")
    func startSessionRollsBackWhenStartMonitoringThrows() async {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()
        mockMonitoring.startActivityMonitoringError = TestError()

        let now = Date()
        mockRepo.stubbedStartSessionResult = SessionRecord(
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        do {
            _ = try await uc(blocklistId: UUID(), duration: SessionDuration.preset(30)!, now: now)
            Issue.record("expected throw")
        } catch {
            #expect(mockShield.applyShieldCallCount == 1)
            #expect(mockMonitoring.startActivityMonitoringCallCount == 1)
            #expect(mockShield.clearShieldCallCount == 1)
            #expect(mockMonitoring.stopActivityMonitoringCallCount == 1)
            #expect(mockRepo.finalizeActiveSessionCallCount == 1)
            #expect(mockRepo.finalizeActiveSessionLastOutcome == .cancelledByUser)
            #expect(error is TestError)
        }
    }

    @Test("reads current blocklist from ObserveBlocklistUseCase")
    func startSessionReadsCurrentBlocklistFromObserveUseCase() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        let customId = UUID()
        mockObserveBlocklist.subject.send(Blocklist.empty(id: customId))
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()

        let now = Date()
        mockRepo.stubbedStartSessionResult = SessionRecord(
            blocklistId: customId,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        _ = try await uc(blocklistId: customId, duration: SessionDuration.preset(30)!, now: now)
        #expect(mockShield.applyShieldLastBlocklistId == customId)
    }

    // MARK: - Notification scheduling

    @Test("schedules notification after monitoring success")
    func schedulesNotification_afterMonitoringSuccess() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()

        let blocklistId = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = SessionRecord(
            blocklistId: blocklistId,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        mockRepo.stubbedStartSessionResult = expected

        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        _ = try await uc(blocklistId: blocklistId, duration: SessionDuration.preset(30)!, now: now)

        #expect(mockScheduleNotification.calls.count == 1)
        #expect(mockScheduleNotification.calls.first?.sessionId == expected.id)
        #expect(mockScheduleNotification.calls.first?.plannedEndAt == expected.plannedEndAt)
        #expect(mockScheduleNotification.calls.first?.durationMinutes == 30)
    }

    @Test("does NOT schedule notification when shield fails")
    func doesNotScheduleNotification_whenShieldFails() async {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()
        mockShield.applyShieldError = TestError()

        let now = Date()
        mockRepo.stubbedStartSessionResult = SessionRecord(
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        do {
            _ = try await uc(blocklistId: UUID(), duration: SessionDuration.preset(30)!, now: now)
            Issue.record("expected throw")
        } catch {
            #expect(mockScheduleNotification.calls.isEmpty, "must not schedule notification on rollback path")
        }
    }

    @Test("does NOT schedule notification when monitoring fails")
    func doesNotScheduleNotification_whenMonitoringFails() async {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()
        mockMonitoring.startActivityMonitoringError = TestError()

        let now = Date()
        mockRepo.stubbedStartSessionResult = SessionRecord(
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        do {
            _ = try await uc(blocklistId: UUID(), duration: SessionDuration.preset(30)!, now: now)
            Issue.record("expected throw")
        } catch {
            #expect(mockScheduleNotification.calls.isEmpty, "must not schedule notification on rollback path")
        }
    }

    @Test("notification failure does NOT propagate (best-effort)")
    func scheduleNotificationFailure_doesNotPropagate() async throws {
        let mockRepo = MockSessionRepository()
        let mockShield = MockSessionShieldRepository()
        let mockMonitoring = MockSessionActivityMonitoringRepository()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        let mockScheduleNotification = MockScheduleSessionEndNotificationUseCase()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = SessionRecord(
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        mockRepo.stubbedStartSessionResult = expected

        let uc = StartSessionUseCaseImpl(
            repository: mockRepo,
            shield: mockShield,
            monitoring: mockMonitoring,
            observeBlocklist: mockObserveBlocklist,
            scheduleEndNotification: mockScheduleNotification
        )
        let returned = try await uc(blocklistId: UUID(), duration: SessionDuration.preset(30)!, now: now)

        #expect(returned == expected)
        #expect(mockRepo.finalizeActiveSessionCallCount == 0)
        #expect(mockShield.clearShieldCallCount == 0)
        #expect(mockMonitoring.stopActivityMonitoringCallCount == 0)
    }
}
