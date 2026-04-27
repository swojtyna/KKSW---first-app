import Foundation
import Combine
import Testing
@testable import DeluluDetox

@Suite("ObserveStatsUseCase")
struct ObserveStatsUseCaseTests {

    @Test("emits stats whenever history emits")
    func emitsStats_wheneverHistoryEmits() {
        let history = MockObserveSessionHistoryUseCase()
        let compute = MockComputeStatsUseCase()
        compute.stubResult = .empty
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let sut = ObserveStatsUseCaseImpl(observeHistory: history, compute: compute, clock: { fixedNow })

        var emissions: [Stats] = []
        let cancellable = sut.execute().sink { emissions.append($0) }
        defer { cancellable.cancel() }

        #expect(emissions.count == 1)
        #expect(emissions.first?.totalCount == 0)

        compute.stubResult = Stats(
            currentStreak: 3,
            longestStreak: 3,
            totalCount: 3,
            last7DaysFlags: Array(repeating: true, count: 3) + Array(repeating: false, count: 4),
            todayWeekdayIndex: 2,
            completedDaysSet: []
        )
        history.subject.send([])

        #expect(emissions.count == 2)
        #expect(emissions.last?.currentStreak == 3)
        #expect(compute.callLog.last?.now == fixedNow)
    }

    @Test("clock is injected for determinism")
    func clockInjected_forDeterminism() {
        let history = MockObserveSessionHistoryUseCase()
        let compute = MockComputeStatsUseCase()
        let fixedNow = Date(timeIntervalSince1970: 0)
        let sut = ObserveStatsUseCaseImpl(observeHistory: history, compute: compute, clock: { fixedNow })

        let cancellable = sut.execute().sink { _ in }
        defer { cancellable.cancel() }

        history.subject.send([])
        history.subject.send([])

        #expect(!compute.callLog.isEmpty)
        for call in compute.callLog {
            #expect(call.now == fixedNow)
        }
    }
}
