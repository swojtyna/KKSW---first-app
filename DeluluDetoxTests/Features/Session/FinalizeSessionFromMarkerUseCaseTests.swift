import Foundation
import Testing
@testable import DeluluDetox

@Suite("FinalizeSessionFromMarkerUseCase")
@MainActor
struct FinalizeSessionFromMarkerUseCaseTests {

    struct TestError: Error, Equatable {}

    @Test("consumes marker and ends session when ids match")
    func finalizeFromMarkerConsumesMarkerAndEndsSessionWhenIdsMatch() async throws {
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
        let now = plannedEnd.addingTimeInterval(5)
        let finalized = try await uc(now: now)

        #expect(finalized)
        #expect(mockRepo.consumeFinalizeMarkerCallCount == 1)
        #expect(mockEnd.callCount == 1)
        #expect(mockEnd.lastOutcome == .completed)
        #expect(mockEnd.lastActualEndAt == plannedEnd)
    }

    @Test("ignores stale marker with mismatched session id")
    func finalizeFromMarkerIgnoresStaleMarker() async throws {
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

        #expect(!finalized)
        #expect(mockRepo.consumeFinalizeMarkerCallCount == 1)
        #expect(mockEnd.callCount == 0)
    }

    @Test("no-op when no marker exists")
    func finalizeFromMarkerIsNoOpWhenNoMarkerExists() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        let finalized = try await uc(now: Date())

        #expect(!finalized)
        #expect(mockRepo.consumeFinalizeMarkerCallCount == 1)
        #expect(mockEnd.callCount == 0)
    }

    // MARK: - Permission prompt

    @Test("schedules permission prompt after completed finalize")
    func schedulesPermissionPrompt_afterCompletedFinalize() async throws {
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

        #expect(didFinalize)
        #expect(mockEnd.callCount == 1)
        #expect(mockEnd.lastOutcome == .completed)
        #expect(mockPrompt.callCount == 1, "D-13: prompt MUST fire after successful completed finalize")
    }

    @Test("does NOT schedule permission prompt when marker is stale")
    func doesNotSchedulePermissionPrompt_whenMarkerStale() async throws {
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

        #expect(mockPrompt.callCount == 0, "stale marker must not reach the prompt hook")
    }

    @Test("does NOT schedule permission prompt when no marker")
    func doesNotSchedulePermissionPrompt_whenNoMarker() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        let mockPrompt = MockSchedulePermissionPromptUseCase()

        let uc = FinalizeSessionFromMarkerUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            schedulePermissionPrompt: mockPrompt
        )
        _ = try await uc(now: Date())

        #expect(mockPrompt.callCount == 0, "no marker → no finalize → no prompt")
    }

    @Test("does NOT schedule permission prompt when endSession throws")
    func doesNotSchedulePermissionPrompt_whenEndSessionThrows() async {
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
            Issue.record("expected throw from endSession")
        } catch {
            #expect(mockPrompt.callCount == 0,
                    "prompt must be gated on successful finalize; endSession throw skips the prompt")
        }
    }
}

// MARK: - Private Helpers

private extension FinalizeSessionFromMarkerUseCaseTests {
    func makeActive(id: UUID, plannedEnd: Date = Date().addingTimeInterval(1800)) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: plannedEnd,
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }
}
