import Observation
import os

@Observable
final class DenialViewModel {
    private(set) var isRequesting = false
    private(set) var error: String?

    private let requestAuth: RequestScreenTimeAuthUseCase
    var onAuthorized: (() -> Void)?

    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Denial")

    init(requestAuth: RequestScreenTimeAuthUseCase, onAuthorized: (() -> Void)? = nil) {
        self.requestAuth = requestAuth
        self.onAuthorized = onAuthorized
    }

    @MainActor
    func retryTapped() async {
        isRequesting = true
        error = nil
        do {
            try await requestAuth()
            logger.info("Screen Time authorization granted on retry")
            onAuthorized?()
        } catch {
            logger.error("Retry authorization failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
        isRequesting = false
    }
}
