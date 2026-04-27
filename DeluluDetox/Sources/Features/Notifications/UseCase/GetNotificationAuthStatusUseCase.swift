import Foundation
import UserNotifications

protocol GetNotificationAuthStatusUseCase: Sendable {
    func execute() async -> UNAuthorizationStatus
}

struct GetNotificationAuthStatusUseCaseImpl: GetNotificationAuthStatusUseCase {
    let repository: LocalNotificationRepository

    func execute() async -> UNAuthorizationStatus {
        await repository.authorizationStatus()
    }
}
