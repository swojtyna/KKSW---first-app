import FamilyControls

final class ScreenTimeAuthRepositoryImpl: ScreenTimeAuthRepository, @unchecked Sendable {
    var authorizationStatus: AuthorizationStatus {
        AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}
