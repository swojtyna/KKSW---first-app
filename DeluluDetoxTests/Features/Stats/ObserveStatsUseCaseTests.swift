import XCTest
import Combine
@testable import DeluluDetox

/// Verifies the Combine pipeline: `ObserveSessionHistoryUseCase` emissions →
/// `ComputeStatsUseCase(history:, now:)` → `AnyPublisher<Stats, Never>`.
/// `now` is clock-injected for determinism.
final class ObserveStatsUseCaseTests: XCTestCase {

    func testEmitsStats_wheneverHistoryEmits() {
        let history = MockObserveSessionHistoryUseCase()
        let compute = MockComputeStatsUseCase()
        compute.stubResult = .empty
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let sut = ObserveStatsUseCaseImpl(observeHistory: history, compute: compute, clock: { fixedNow })

        var emissions: [Stats] = []
        let cancellable = sut().sink { emissions.append($0) }
        defer { cancellable.cancel() }

        // Pipe is live — first emission happened immediately (CurrentValueSubject seed).
        XCTAssertEqual(emissions.count, 1)
        XCTAssertEqual(emissions.first?.totalCount, 0)

        // Swap the compute result, then push a new history — pipeline must re-emit.
        compute.stubResult = Stats(
            currentStreak: 3,
            longestStreak: 3,
            totalCount: 3,
            last7DaysFlags: Array(repeating: true, count: 3) + Array(repeating: false, count: 4),
            todayWeekdayIndex: 2,
            completedDaysSet: []
        )
        history.subject.send([])

        XCTAssertEqual(emissions.count, 2)
        XCTAssertEqual(emissions.last?.currentStreak, 3)
        XCTAssertEqual(compute.callLog.last?.now, fixedNow)
    }

    func testClockInjected_forDeterminism() {
        let history = MockObserveSessionHistoryUseCase()
        let compute = MockComputeStatsUseCase()
        let fixedNow = Date(timeIntervalSince1970: 0)
        let sut = ObserveStatsUseCaseImpl(observeHistory: history, compute: compute, clock: { fixedNow })

        let cancellable = sut().sink { _ in }
        defer { cancellable.cancel() }

        history.subject.send([])
        history.subject.send([])

        XCTAssertFalse(compute.callLog.isEmpty)
        for call in compute.callLog {
            XCTAssertEqual(call.now, fixedNow)
        }
    }
}
