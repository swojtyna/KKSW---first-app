import Foundation
import UserNotifications
@testable import DeluluDetox

/// Test double for `LocalNotificationRepository`. Records every call so tests
/// can assert ordering + payloads. Thread-safety: tests are single-task; any
/// concurrent access would surface via `@unchecked Sendable` and must be fixed.
final class MockLocalNotificationRepository: LocalNotificationRepository, @unchecked Sendable {
    // Configurable
    var stubAuthorizationStatus: UNAuthorizationStatus = .authorized
    var stubPending: [UNNotificationRequest] = []
    var stubRequestAuthorizationResult: Result<Bool, Error> = .success(true)

    // Captured
    private(set) var authorizationStatusCallCount = 0
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifierSets: [[String]] = []
    private(set) var removedPrefixes: [String] = []
    private(set) var requestAuthorizationCallCount = 0
    private(set) var requestedAuthorizationOptions: [UNAuthorizationOptions] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusCallCount += 1
        return stubAuthorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        requestedAuthorizationOptions.append(options)
        return try stubRequestAuthorizationResult.get()
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        stubPending
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        removedIdentifierSets.append(ids)
        stubPending.removeAll { ids.contains($0.identifier) }
    }

    func removePendingNotificationRequests(withIdentifierPrefix prefix: String) async {
        removedPrefixes.append(prefix)
        stubPending.removeAll { $0.identifier.hasPrefix(prefix) }
    }
}
