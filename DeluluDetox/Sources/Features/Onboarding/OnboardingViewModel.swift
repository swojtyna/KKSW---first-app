import Observation
import os

@Observable
final class OnboardingViewModel {
    private(set) var isRequesting = false
    private(set) var error: String?

    private let requestAuth: RequestScreenTimeAuthUseCase
    var onAuthorized: (() -> Void)?

    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Onboarding")

    init(requestAuth: RequestScreenTimeAuthUseCase, onAuthorized: (() -> Void)? = nil) {
        self.requestAuth = requestAuth
        self.onAuthorized = onAuthorized
    }

    @MainActor
    func grantAccessTapped() async {
        isRequesting = true
        error = nil
        do {
            try await requestAuth()
            logger.info("Screen Time authorization granted")
            onAuthorized?()
        } catch {
            logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
        isRequesting = false
    }
}
