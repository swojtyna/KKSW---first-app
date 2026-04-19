import Observation
import os

@MainActor
@Observable
final class DenialViewModel: @unchecked Sendable {
    private(set) var isRequesting = false
    private(set) var error: String?

    @ObservationIgnored
    @LazyInjected private var requestAuth: RequestScreenTimeAuthUseCase

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Denial")

    init() {}

    func retryTapped() async {
        isRequesting = true
        error = nil
        do {
            try await requestAuth()
            logger.info("Screen Time authorization granted on retry")
            // Event flow przez Combine publisher na repo.statusSubject — AppRootVM aktualizuje destination (D-11).
        } catch {
            logger.error("Retry authorization failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }
        isRequesting = false
    }
}
