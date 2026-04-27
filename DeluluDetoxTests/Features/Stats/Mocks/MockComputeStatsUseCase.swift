import Foundation
@testable import DeluluDetox

/// Test double for `ComputeStatsUseCase`. Records every `(history, now)` call
/// and returns `stubResult` (default `.empty`).
final class MockComputeStatsUseCase: ComputeStatsUseCase, @unchecked Sendable {
    var stubResult: Stats = .empty
    private(set) var callLog: [(history: [SessionRecord], now: Date)] = []

    func execute(history: [SessionRecord], now: Date) -> Stats {
        callLog.append((history, now))
        return stubResult
    }
}
