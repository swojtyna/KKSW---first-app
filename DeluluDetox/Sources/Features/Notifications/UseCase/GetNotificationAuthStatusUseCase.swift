import Foundation
import UserNotifications

protocol GetNotificationAuthStatusUseCase: Sendable {
    func callAsFunction() async -> UNAuthorizationStatus
}

struct GetNotificationAuthStatusUseCaseImpl: GetNotificationAuthStatusUseCase {
    let repository: LocalNotificationRepository

    func callAsFunction() async -> UNAuthorizationStatus {
        await repository.authorizationStatus()
    }
}
