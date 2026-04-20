import XCTest
@testable import DeluluDetox

@MainActor
final class FinalizeSessionFromMarkerUseCaseTests: XCTestCase {
    struct TestError: Error, Equatable {}

    private func makeActive(id: UUID, plannedEnd: Date = Date().addingTimeInterval(1800)) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: plannedEnd,
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }

    func testFinalizeFromMarkerConsumesMarkerAndEndsSessionWhenIdsMatch() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()

        let sessionId = UUID()
        let plannedEnd = Date(timeIntervalSince1970: 1_700_000_000 + 1800)
        mockRepo.activeSubject.send(makeActive(id: sessionId, plannedEnd: plannedEnd))
        mockRepo.stubbedConsumedMarker = SessionFinalizeMarker(
            sessionId: sessionId,
            finalizedAt: plannedEnd,
            source: .damIntervalDidEnd
        )

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        let now = plannedEnd.addingTimeInterval(5)  // caller clock slightly after planned end
        let finalized = try await uc(now: now)

        XCTAssertTrue(finalized)
        XCTAssertEqual(mockRepo.consumeFinalizeMarkerCallCount, 1)
        XCTAssertEqual(mockEnd.callCount, 1)
        XCTAssertEqual(mockEnd.lastOutcome, .completed)
        // actualEndAt is capped at plannedEndAt.
        XCTAssertEqual(mockEnd.lastActualEndAt, plannedEnd)
    }

    func testFinalizeFromMarkerIgnoresStaleMarker() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()

        let activeId = UUID()
        let staleId = UUID()
        mockRepo.activeSubject.send(makeActive(id: activeId))
        mockRepo.stubbedConsumedMarker = SessionFinalizeMarker(
            sessionId: staleId,
            finalizedAt: Date(),
            source: .damIntervalDidEnd
        )

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        let finalized = try await uc(now: Date())

        XCTAssertFalse(finalized)
        XCTAssertEqual(mockRepo.consumeFinalizeMarkerCallCount, 1)  // destructive consume
        XCTAssertEqual(mockEnd.callCount, 0)
    }

    func testFinalizeFromMarkerIsNoOpWhenNoMarkerExists() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()
        // stubbedConsumedMarker stays nil.

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        let finalized = try await uc(now: Date())

        XCTAssertFalse(finalized)
        XCTAssertEqual(mockRepo.consumeFinalizeMarkerCallCount, 1)
        XCTAssertEqual(mockEnd.callCount, 0)
    }

    // MARK: - Plan 06-03 (D-13 lazy prompt) extensions

    func testSchedulesPermissionPrompt_afterCompletedFinalize() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()

        let sessionId = UUID()
        let plannedEnd = Date(timeIntervalSince1970: 1_700_000_000 + 1800)
        mockRepo.activeSubject.send(makeActive(id: sessionId, plannedEnd: plannedEnd))
        mockRepo.stubbedConsumedMarker = SessionFinalizeMarker(
            sessionId: sessionId,
            finalizedAt: plannedEnd,
            source: .damIntervalDidEnd
        )

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        let didFinalize = try await uc(now: plannedEnd)

        XCTAssertTrue(didFinalize)
        XCTAssertEqual(mockEnd.callCount, 1)
        XCTAssertEqual(mockEnd.lastOutcome, .completed)
        XCTAssertEqual(mockPrompt.callCount, 1,
                       "D-13: prompt MUST fire after successful completed finalize")
    }

    func testDoesNotSchedulePermissionPrompt_whenMarkerStale() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()

        let activeId = UUID()
        let staleId = UUID()
        mockRepo.activeSubject.send(makeActive(id: activeId))
        mockRepo.stubbedConsumedMarker = SessionFinalizeMarker(
            sessionId: staleId,
            finalizedAt: Date(),
            source: .damIntervalDidEnd
        )

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        _ = try await uc(now: Date())

        XCTAssertEqual(mockPrompt.callCount, 0,
                       "stale marker must not reach the prompt hook")
    }

    func testDoesNotSchedulePermissionPrompt_whenNoMarker() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()
        // stubbedConsumedMarker stays nil

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        _ = try await uc(now: Date())

        XCTAssertEqual(mockPrompt.callCount, 0, "no marker → no finalize → no prompt")
    }

    func testDoesNotSchedulePermissionPrompt_whenEndSessionThrows() async {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        mockEnd.stubbedError = TestError()
        let mockPrompt = MockSchedulePermissionPromptUseCase()

        let sessionId = UUID()
        mockRepo.activeSubject.send(makeActive(id: sessionId))
        mockRepo.stubbedConsumedMarker = SessionFinalizeMarker(
            sessionId: sessionId,
            finalizedAt: Date(),
            source: .damIntervalDidEnd
        )

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        do {
            _ = try await uc(now: Date())
            XCTFail("expected throw from endSession")
        } catch {
            XCTAssertEqual(mockPrompt.callCount, 0,
                           "prompt must be gated on successful finalize; endSession throw skips the prompt")
        }
    }
}
