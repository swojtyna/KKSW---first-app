import Combine
import Foundation
@testable import DeluluDetox

final class MockSessionRepository: SessionRepository, @unchecked Sendable {
    // MARK: Publishers (exposed subjects so tests can drive emissions).
    let activeSubject = CurrentValueSubject<SessionRecord?, Never>(nil)
    let historySubject = CurrentValueSubject<[SessionRecord], Never>([])

    var activeSessionPublisher: AnyPublisher<SessionRecord?, Never> {
        activeSubject.eraseToAnyPublisher()
    }
    var historyPublisher: AnyPublisher<[SessionRecord], Never> {
        historySubject.eraseToAnyPublisher()
    }

    // MARK: startSession
    private(set) var startSessionCallCount = 0
    private(set) var startSessionLastBlocklistId: UUID?
    private(set) var startSessionLastDuration: SessionDuration?
    private(set) var startSessionLastNow: Date?
    var startSessionError: Error?
    var stubbedStartSessionResult: SessionRecord?

    func startSession(blocklistId: UUID, duration: SessionDuration, now: Date) async throws -> SessionRecord {
        startSessionCallCount += 1
        startSessionLastBlocklistId = blocklistId
        startSessionLastDuration = duration
        startSessionLastNow = now
        if let startSessionError { throw startSessionError }
        guard let stubbedStartSessionResult else {
            fatalError("MockSessionRepository.stubbedStartSessionResult not set")
        }
        activeSubject.send(stubbedStartSessionResult)
        historySubject.send(historySubject.value + [stubbedStartSessionResult])
        return stubbedStartSessionResult
    }

    // MARK: finalizeActiveSession
    private(set) var finalizeActiveSessionCallCount = 0
    private(set) var finalizeActiveSessionLastOutcome: SessionOutcome?
    private(set) var finalizeActiveSessionLastActualEndAt: Date?
    var finalizeActiveSessionError: Error?

    func finalizeActiveSession(outcome: SessionOutcome, actualEndAt: Date) async throws {
        finalizeActiveSessionCallCount += 1
        finalizeActiveSessionLastOutcome = outcome
        finalizeActiveSessionLastActualEndAt = actualEndAt
        if let finalizeActiveSessionError { throw finalizeActiveSessionError }
        activeSubject.send(nil)
    }

    // MARK: consumeFinalizeMarker
    private(set) var consumeFinalizeMarkerCallCount = 0
    var stubbedConsumedMarker: SessionFinalizeMarker?
    var consumeFinalizeMarkerError: Error?

    func consumeFinalizeMarker() async throws -> SessionFinalizeMarker? {
        consumeFinalizeMarkerCallCount += 1
        if let consumeFinalizeMarkerError { throw consumeFinalizeMarkerError }
        let value = stubbedConsumedMarker
        stubbedConsumedMarker = nil   // destructive-consume semantics
        return value
    }

    // MARK: loadActiveSessionFromDisk
    private(set) var loadActiveSessionFromDiskCallCount = 0
    var stubbedDiskActiveSession: SessionRecord?
    var loadActiveSessionFromDiskError: Error?

    func loadActiveSessionFromDisk() async throws -> SessionRecord? {
        loadActiveSessionFromDiskCallCount += 1
        if let loadActiveSessionFromDiskError { throw loadActiveSessionFromDiskError }
        return stubbedDiskActiveSession
    }
}
