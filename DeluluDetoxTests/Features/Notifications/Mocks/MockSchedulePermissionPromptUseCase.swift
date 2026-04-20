import Foundation
@testable import DeluluDetox

final class MockSchedulePermissionPromptUseCase: SchedulePermissionPromptUseCase, @unchecked Sendable {
    private(set) var callCount: Int = 0

    func callAsFunction() async {
        callCount += 1
    }
}
