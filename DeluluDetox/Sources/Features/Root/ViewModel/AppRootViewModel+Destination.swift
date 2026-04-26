import FamilyControls
import SwiftUINavigation

extension AppRootViewModel {

    @CasePathable
    enum Destination: Equatable {
        case onboarding
        case notificationsOnboarding
        case denial
        case home
    }

    static func map(_ status: AuthorizationStatus) -> Destination {
        switch status {
        case .approved: return .home
        case .denied: return .denial
        default: return .onboarding
        }
    }
}
