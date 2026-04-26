import Combine
import Foundation
import Observation
import SwiftUINavigation
import os

@MainActor
@Observable
final class CountdownViewModel: @unchecked Sendable {

    let session: SessionRecord
    private(set) var remainingSeconds: Int
    private(set) var progress: Double     // 1.0 at start, 0.0 at end
    var destination: Destination?

    @ObservationIgnored
    @LazyInjected private var endSession: EndSessionUseCase

    @ObservationIgnored
    private let dateProvider: @Sendable () -> Date

    @ObservationIgnored
    private let clock: TickClock

    @ObservationIgnored
    private var tickToken: (any TickCancellable)?

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "CountdownVM"
    )

    init(
        session: SessionRecord,
        clock: TickClock = SystemTickClock(),
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.clock = clock
        self.dateProvider = dateProvider
        let remaining = Self.computeRemainingSeconds(
            plannedEndAt: session.plannedEndAt,
            now: dateProvider()
        )
        self.remainingSeconds = remaining
        self.progress = Self.computeProgress(
            remainingSeconds: remaining,
            plannedDurationSeconds: session.plannedDurationSeconds
        )
        startTicking()
    }

    // MARK: - Intents

    func confirmEarlyEnd() async {
        do {
            try await endSession(outcome: .cancelledByUser, actualEndAt: dateProvider())
            destination = nil
            logger.info("early-end confirmed session id=\(self.session.id.uuidString, privacy: .public)")
        } catch {
            logger.error("early-end failed: \(String(describing: error), privacy: .public)")
            // Keep destination so user can retry.
        }
    }

    func onDisappear() {
        tickToken?.cancel()
        tickToken = nil
    }

    // MARK: - Private

    private func startTicking() {
        tickToken = clock.schedule(interval: 1.0) { [weak self] in
            self?.tick()
        }
    }

    private func tick() {
        let now = dateProvider()
        let newRemaining = Self.computeRemainingSeconds(
            plannedEndAt: session.plannedEndAt,
            now: now
        )
        remainingSeconds = newRemaining
        progress = Self.computeProgress(
            remainingSeconds: newRemaining,
            plannedDurationSeconds: session.plannedDurationSeconds
        )
        if newRemaining == 0 {
            tickToken?.cancel()
            tickToken = nil
        }
    }

    private static func computeRemainingSeconds(plannedEndAt: Date, now: Date) -> Int {
        max(0, Int(plannedEndAt.timeIntervalSince(now).rounded()))
    }

    private static func computeProgress(remainingSeconds: Int, plannedDurationSeconds: Int) -> Double {
        guard plannedDurationSeconds > 0 else { return 0 }
        let clamped = min(remainingSeconds, plannedDurationSeconds)
        return Double(clamped) / Double(plannedDurationSeconds)
    }
}
