import FamilyControls

protocol ScreenTimeAuthRepository: Sendable {
    var authorizationStatus: AuthorizationStatus { get }
    func requestAuthorization() async throws
}
