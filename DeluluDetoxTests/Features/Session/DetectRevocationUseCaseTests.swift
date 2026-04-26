import Foundation
@preconcurrency import FamilyControls
import Testing
@testable import DeluluDetox

@Suite("DetectRevocationUseCase")
@MainActor
struct DetectRevocationUseCaseTests {

    @Test("finalizes session with brokenByRevoke when active and not approved")
    func detectRevocationFinalizesWhenActiveAndNotApproved() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        mockRepo.activeSubject.send(makeActive())

        let uc = DetectRevocationUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            authorizationStatusProvider: { .denied }
        )
        let now = Date(timeIntervalSince1970: 1_700_000_500)
        let finalized = try await uc(now: now)

        #expect(finalized)
        #expect(mockEnd.callCount == 1)
        #expect(mockEnd.lastOutcome == .brokenByRevoke)
        #expect(mockEnd.lastActualEndAt == now)
    }

    @Test("no-op when active and approved")
    func detectRevocationIsNoOpWhenActiveAndApproved() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()
        mockRepo.activeSubject.send(makeActive())

        let uc = DetectRevocationUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            authorizationStatusProvider: { .approved }
        )
        let finalized = try await uc(now: Date())

        #expect(!finalized)
        #expect(mockEnd.callCount == 0)
    }

    @Test("no-op when no active session")
    func detectRevocationIsNoOpWhenNoActiveSession() async throws {
        let mockRepo = MockSessionRepository()
        let mockEnd = MockEndSessionUseCase()

        let uc = DetectRevocationUseCaseImpl(
            repository: mockRepo,
            endSession: mockEnd,
            authorizationStatusProvider: { .denied }
        )
        let finalized = try await uc(now: Date())

        #expect(!finalized)
        #expect(mockEnd.callCount == 0)
    }
}

// MARK: - Private Helpers

private extension DetectRevocationUseCaseTests {
    func makeActive() -> SessionRecord {
        SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }
}
