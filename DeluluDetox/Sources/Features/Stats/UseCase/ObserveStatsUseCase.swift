import Combine
import Foundation

/// Reactive projection of session history into `Stats`. Bridges
/// `ObserveSessionHistoryUseCase` (Phase 3) with `ComputeStatsUseCase` (Plan 01).
///
/// RESEARCH explicitly chose this over a `StatsRepository` — a dedicated
/// repository would need to depend on `SessionRepository`, violating the
/// hard rule Repo ↛ Repo. The UseCase layer is the correct place to cross
/// feature boundaries.
protocol ObserveStatsUseCase: Sendable {
    func execute() -> AnyPublisher<Stats, Never>
}

final class ObserveStatsUseCaseImpl: ObserveStatsUseCase, @unchecked Sendable {
    private let observeHistory: ObserveSessionHistoryUseCase
    private let compute: ComputeStatsUseCase
    private let clock: @Sendable () -> Date

    init(
        observeHistory: ObserveSessionHistoryUseCase,
        compute: ComputeStatsUseCase,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.observeHistory = observeHistory
        self.compute = compute
        self.clock = clock
    }

    func execute() -> AnyPublisher<Stats, Never> {
        observeHistory.execute()
            .map { [compute, clock] history in
                compute.execute(history: history, now: clock())
            }
            .eraseToAnyPublisher()
    }
}
