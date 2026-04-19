import Observation
import os

@MainActor
@Observable
final class OnboardingViewModel: @unchecked Sendable {
    private(set) var isRequesting = false
    private(set) var error: String?

    @ObservationIgnored
    @LazyInjected private var requestAuth: RequestScreenTimeAuthUseCase

    // TRANSITIONAL -- replaced by Combine publisher subscription in 01.1-04 (Root VM refactor).
    // Keeps AppRootView.swift checkAuthorization wiring functional during Wave 3.
    var onAuthorized: (() -> Void)?

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Onboarding")

    init() {}

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
