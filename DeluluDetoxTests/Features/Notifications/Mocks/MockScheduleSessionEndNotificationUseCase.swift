import Foundation
@testable import DeluluDetox

final class MockScheduleSessionEndNotificationUseCase: ScheduleSessionEndNotificationUseCase, @unchecked Sendable {
    struct Call: Equatable {
        let sessionId: UUID
        let plannedEndAt: Date
        let durationMinutes: Int
    }
    private(set) var calls: [Call] = []

    func execute(sessionId: UUID, plannedEndAt: Date, durationMinutes: Int) async {
        calls.append(Call(sessionId: sessionId, plannedEndAt: plannedEndAt, durationMinutes: durationMinutes))
    }
}
