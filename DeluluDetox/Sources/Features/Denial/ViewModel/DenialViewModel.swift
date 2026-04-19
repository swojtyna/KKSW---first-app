import Observation
import os

@MainActor
@Observable
final class DenialViewModel: @unchecked Sendable {
    private(set) var isRequesting = false

    @ObservationIgnored
    @LazyInjected private var requestAuth: RequestScreenTimeAuthUseCase

    // TRANSITIONAL -- replaced by Combine publisher subscription in 01.1-04.
    var onAuthorized: (() -> Void)?

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "Denial")

    init() {}

    func retryTapped() async {
        isRequesting = true
        do {
            try await requestAuth()
            logger.info("Screen Time authorization granted on retry")
            onAuthorized?()
        } catch {
            logger.error("Retry authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        isRequesting = false
    }
}
