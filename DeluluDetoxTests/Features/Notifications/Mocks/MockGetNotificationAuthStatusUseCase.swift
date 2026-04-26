import Foundation
import UserNotifications
@testable import DeluluDetox

final class MockGetNotificationAuthStatusUseCase: GetNotificationAuthStatusUseCase, @unchecked Sendable {
    var stubStatus: UNAuthorizationStatus = .authorized

    func callAsFunction() async -> UNAuthorizationStatus {
        stubStatus
    }
}
