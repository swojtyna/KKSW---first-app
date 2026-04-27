import Foundation
@testable import DeluluDetox

/// NTF-02 mock — call log for Plan 06-04 Task 2 integration tests
/// (SyncScheduleWithSystemUseCaseTests + AppRootViewModelTests foreground).
final class MockReconcileScheduleNotificationsUseCase: ReconcileScheduleNotificationsUseCase, @unchecked Sendable {
    private(set) var receivedSchedules: [Schedule] = []

    func execute(schedule: Schedule) async {
        receivedSchedules.append(schedule)
    }
}
