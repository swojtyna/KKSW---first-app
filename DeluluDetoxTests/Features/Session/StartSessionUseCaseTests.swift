import XCTest
import Combine
@testable import DeluluDetox

@MainActor
final class StartSessionUseCaseTests: XCTestCase {
    struct TestError: Error, Equatable {}

    func testStartSessionHappyPathInvokesRepoThenShieldThenMonitoring() async throws {
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

        XCTAssertEqual(returned, expected)
        XCTAssertEqual(mockRepo.startSessionCallCount, 1)
        XCTAssertEqual(mockRepo.startSessionLastBlocklistId, blocklistId)
        XCTAssertEqual(mockShield.applyShieldCallCount, 1)
        XCTAssertEqual(mockMonitoring.startActivityMonitoringCallCount, 1)
        XCTAssertEqual(mockShield.clearShieldCallCount, 0)
        XCTAssertEqual(mockMonitoring.stopActivityMonitoringCallCount, 0)
        XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 0)
    }

    func testStartSessionRollsBackWhenApplyShieldThrows() async {
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
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(mockRepo.startSessionCallCount, 1)
            XCTAssertEqual(mockShield.applyShieldCallCount, 1)
            // Monitoring should NOT have been started (failed at step 2).
            XCTAssertEqual(mockMonitoring.startActivityMonitoringCallCount, 0)
            // Rollback: clear + stop + finalize as cancelledByUser.
            XCTAssertEqual(mockShield.clearShieldCallCount, 1)
            XCTAssertEqual(mockMonitoring.stopActivityMonitoringCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionLastOutcome, .cancelledByUser)
            XCTAssertTrue(error is TestError)
        }
    }

    func testStartSessionRollsBackWhenStartMonitoringThrows() async {
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
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(mockShield.applyShieldCallCount, 1)
            XCTAssertEqual(mockMonitoring.startActivityMonitoringCallCount, 1)
            XCTAssertEqual(mockShield.clearShieldCallCount, 1)
            XCTAssertEqual(mockMonitoring.stopActivityMonitoringCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionLastOutcome, .cancelledByUser)
            XCTAssertTrue(error is TestError)
        }
    }

    func testStartSessionReadsCurrentBlocklistFromObserveUseCase() async throws {
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
        XCTAssertEqual(mockShield.applyShieldLastBlocklistId, customId)
    }

    // MARK: - Plan 06-03 (NTF-01 §H1) extensions

    func testSchedulesNotification_afterMonitoringSuccess() async throws {
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

        XCTAssertEqual(mockScheduleNotification.calls.count, 1)
        XCTAssertEqual(mockScheduleNotification.calls.first?.sessionId, expected.id)
        XCTAssertEqual(mockScheduleNotification.calls.first?.plannedEndAt, expected.plannedEndAt)
        XCTAssertEqual(mockScheduleNotification.calls.first?.durationMinutes, 30)
    }

    func testDoesNotScheduleNotification_whenShieldFails() async {
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
            XCTFail("expected throw")
        } catch {
            XCTAssertTrue(mockScheduleNotification.calls.isEmpty, "must not schedule notification on rollback path")
        }
    }

    func testDoesNotScheduleNotification_whenMonitoringFails() async {
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
            XCTFail("expected throw")
        } catch {
            XCTAssertTrue(mockScheduleNotification.calls.isEmpty, "must not schedule notification on rollback path")
        }
    }

    func testScheduleNotificationFailure_doesNotPropagate() async throws {
        // The mock cannot throw; this test asserts the SEMANTIC contract: the UC
        // returns the record AFTER a best-effort schedule call, without rollback.
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

        // Returned record matches expected — no rollback triggered by the best-effort notification hop.
        XCTAssertEqual(returned, expected)
        XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 0)
        XCTAssertEqual(mockShield.clearShieldCallCount, 0)
        XCTAssertEqual(mockMonitoring.stopActivityMonitoringCallCount, 0)
    }
}
