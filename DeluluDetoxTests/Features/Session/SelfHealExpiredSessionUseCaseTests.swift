import Foundation
import Testing
@testable import DeluluDetox

@Suite("SelfHealExpiredSessionUseCase")
@MainActor
struct SelfHealExpiredSessionUseCaseTests {

    @Test("finalizes expired active session")
    func selfHealFinalizesWhenActiveSessionIsExpired() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plannedEnd = now.addingTimeInterval(-60)
        mockRepo.activeSubject.send(makeActive(plannedEnd: plannedEnd))

        let uc = SelfHealExpiredSessionUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let healed = try await uc(now: now)

        #expect(healed)
        #expect(mockEnd.callCount == 1)
        #expect(mockEnd.lastOutcome == .completed)
        #expect(mockEnd.lastActualEndAt == plannedEnd)
    }

    @Test("no-op when active session is still running")
    func selfHealIsNoOpWhenActiveSessionIsStillRunning() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plannedEnd = now.addingTimeInterval(60)
        mockRepo.activeSubject.send(makeActive(plannedEnd: plannedEnd))

        let uc = SelfHealExpiredSessionUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let healed = try await uc(now: now)

        #expect(!healed)
        #expect(mockEnd.callCount == 0)
    }

    @Test("no-op when no active session exists")
    func selfHealIsNoOpWhenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let uc = SelfHealExpiredSessionUseCaseImpl(repository: mockRepo, endSession: mockEnd)
        let healed = try await uc(now: Date())

        #expect(!healed)
        #expect(mockEnd.callCount == 0)
    }
}

// MARK: - Private Helpers

private extension SelfHealExpiredSessionUseCaseTests {
    func makeActive(id: UUID = UUID(), plannedEnd: Date) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: plannedEnd.addingTimeInterval(-1800),
            plannedEndAt: plannedEnd,
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }
}
