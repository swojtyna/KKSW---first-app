import XCTest
import Combine
@testable import DeluluDetox

@MainActor
final class StartSessionUseCaseTests: XCTestCase {
    struct TestError: Error, Equatable {}

    func testStartSessionHappyPathInvokesRepoThenShieldThenMonitoring() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnforcer = MockSessionEnforcer()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())

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
            enforcer: mockEnforcer,
            observeBlocklist: mockObserveBlocklist
        )
        let returned = try await uc(blocklistId: blocklistId, duration: duration, now: now)

        XCTAssertEqual(returned, expected)
        XCTAssertEqual(mockRepo.startSessionCallCount, 1)
        XCTAssertEqual(mockRepo.startSessionLastBlocklistId, blocklistId)
        XCTAssertEqual(mockEnforcer.applyShieldCallCount, 1)
        XCTAssertEqual(mockEnforcer.startActivityMonitoringCallCount, 1)
        XCTAssertEqual(mockEnforcer.clearShieldCallCount, 0)
        XCTAssertEqual(mockEnforcer.stopActivityMonitoringCallCount, 0)
        XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 0)
    }

    func testStartSessionRollsBackWhenApplyShieldThrows() async {
        let mockRepo = MockSessionRepository()
        let mockEnforcer = MockSessionEnforcer()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        mockEnforcer.applyShieldError = TestError()

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
            enforcer: mockEnforcer,
            observeBlocklist: mockObserveBlocklist
        )
        do {
            _ = try await uc(blocklistId: UUID(), duration: SessionDuration.preset(30)!, now: now)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(mockRepo.startSessionCallCount, 1)
            XCTAssertEqual(mockEnforcer.applyShieldCallCount, 1)
            // Monitoring should NOT have been started (failed at step 2).
            XCTAssertEqual(mockEnforcer.startActivityMonitoringCallCount, 0)
            // Rollback: clear + stop + finalize as cancelledByUser.
            XCTAssertEqual(mockEnforcer.clearShieldCallCount, 1)
            XCTAssertEqual(mockEnforcer.stopActivityMonitoringCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionLastOutcome, .cancelledByUser)
            XCTAssertTrue(error is TestError)
        }
    }

    func testStartSessionRollsBackWhenStartMonitoringThrows() async {
        let mockRepo = MockSessionRepository()
        let mockEnforcer = MockSessionEnforcer()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        mockEnforcer.startActivityMonitoringError = TestError()

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
            enforcer: mockEnforcer,
            observeBlocklist: mockObserveBlocklist
        )
        do {
            _ = try await uc(blocklistId: UUID(), duration: SessionDuration.preset(30)!, now: now)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(mockEnforcer.applyShieldCallCount, 1)
            XCTAssertEqual(mockEnforcer.startActivityMonitoringCallCount, 1)
            XCTAssertEqual(mockEnforcer.clearShieldCallCount, 1)
            XCTAssertEqual(mockEnforcer.stopActivityMonitoringCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionCallCount, 1)
            XCTAssertEqual(mockRepo.finalizeActiveSessionLastOutcome, .cancelledByUser)
            XCTAssertTrue(error is TestError)
        }
    }

    func testStartSessionReadsCurrentBlocklistFromObserveUseCase() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnforcer = MockSessionEnforcer()
        let mockObserveBlocklist = MockObserveBlocklistUseCase()
        let customId = UUID()
        mockObserveBlocklist.subject.send(Blocklist.empty(id: customId))

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
            enforcer: mockEnforcer,
            observeBlocklist: mockObserveBlocklist
        )
        _ = try await uc(blocklistId: customId, duration: SessionDuration.preset(30)!, now: now)
        XCTAssertEqual(mockEnforcer.applyShieldLastBlocklistId, customId)
    }
}
