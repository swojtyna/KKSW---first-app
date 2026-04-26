import Foundation
@testable import DeluluDetox

final class MockCompleteNotificationsOnboardingUseCase: CompleteNotificationsOnboardingUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    func callAsFunction() { callCount += 1 }
}
