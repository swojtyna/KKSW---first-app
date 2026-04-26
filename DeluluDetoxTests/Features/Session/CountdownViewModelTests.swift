import Foundation
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class CountdownViewModelTests {

    struct TestError: Error {}

    // MARK: - Fake TickClock

    final class FakeTickClock: TickClock, @unchecked Sendable {
        var storedTick: (@MainActor () -> Void)?
        var scheduleCallCount = 0

        final class FakeToken: TickCancellable, @unchecked Sendable {
            var cancelled = false
            func cancel() { cancelled = true }
        }

        var lastToken: FakeToken?

        @MainActor
        func schedule(interval: TimeInterval, onTick: @escaping @MainActor () -> Void) -> any TickCancellable {
            scheduleCallCount += 1
            storedTick = onTick
            let token = FakeToken()
            lastToken = token
            return token
        }

        @MainActor
        func advance() {
            storedTick?()
        }
    }

    // MARK: - DateBox helper (avoids "captured var in @Sendable closure" under Swift 6)

    final class DateBox: @unchecked Sendable {
        var value: Date
        init(_ date: Date) { self.value = date }
    }

    let mockEndSession: MockEndSessionUseCase

    init() {
        DIContainer.shared.reset()
        mockEndSession = MockEndSessionUseCase()
        DIContainer.shared.register(EndSessionUseCase.self, scope: .application) { [mockEndSession] _ in mockEndSession }
    }

    // MARK: - Init / compute

    @Test("init sets remaining and progress from session")
    func initSetsRemainingAndProgressFromSession() {
        let session = makeSession()
        let clock = FakeTickClock()
        let vm = CountdownViewModel(
            session: session,
            clock: clock,
            dateProvider: { session.startedAt.addingTimeInterval(600) }
        )
        #expect(vm.remainingSeconds == 1200)
        #expect(abs(vm.progress - 1200.0 / 1800.0) < 0.001)
    }

    @Test("init clamps remaining to zero when session already expired")
    func initClampsRemainingToZeroWhenSessionAlreadyExpired() {
        let session = makeSession()
        let clock = FakeTickClock()
        let vm = CountdownViewModel(
            session: session,
            clock: clock,
            dateProvider: { session.plannedEndAt.addingTimeInterval(10) }
        )
        #expect(vm.remainingSeconds == 0)
        #expect(vm.progress == 0.0)
    }

    // MARK: - Tick

    @Test("tick reduces remaining by one second per fire")
    func tickReducesRemainingByOneSecondPerFire() {
        let session = makeSession()
        let clock = FakeTickClock()
        let nowBox = DateBox(session.startedAt)
        let vm = CountdownViewModel(
            session: session,
            clock: clock,
            dateProvider: { nowBox.value }
        )

        nowBox.value = session.startedAt.addingTimeInterval(1)
        clock.advance()
        #expect(vm.remainingSeconds == 1800 - 1)

        nowBox.value = session.startedAt.addingTimeInterval(2)
        clock.advance()
        #expect(vm.remainingSeconds == 1800 - 2)
    }

    @Test("tick stops at zero and does not go negative")
    func tickStopsAtZeroDoesNotGoNegative() {
        let session = makeSession(duration: 2)
        let clock = FakeTickClock()
        let nowBox = DateBox(session.startedAt)
        let vm = CountdownViewModel(
            session: session,
            clock: clock,
            dateProvider: { nowBox.value }
        )

        nowBox.value = session.startedAt.addingTimeInterval(3)
        clock.advance()
        #expect(vm.remainingSeconds == 0)

        nowBox.value = session.startedAt.addingTimeInterval(4)
        clock.advance()
        #expect(vm.remainingSeconds == 0)
    }

    // MARK: - Early end

    @Test("earlyEndTapped sets confirmEarlyEnd destination")
    func earlyEndTappedSetsConfirmDestination() {
        let session = makeSession()
        let vm = CountdownViewModel(session: session, clock: FakeTickClock())
        vm.earlyEndTapped()
        #expect(vm.destination == .confirmEarlyEnd(session))
    }

    @Test("confirmEarlyEnd invokes EndSessionUseCase with cancelledByUser outcome")
    func confirmEarlyEndInvokesEndSessionUseCaseWithCancelledByUserOutcome() async {
        let session = makeSession()
        let clock = FakeTickClock()
        let fakeNow = session.startedAt.addingTimeInterval(120)
        let vm = CountdownViewModel(session: session, clock: clock, dateProvider: { fakeNow })
        vm.earlyEndTapped()
        await vm.confirmEarlyEnd()

        #expect(mockEndSession.callCount == 1)
        #expect(mockEndSession.lastOutcome == .cancelledByUser)
        #expect(mockEndSession.lastActualEndAt == fakeNow)
        #expect(vm.destination == nil)
    }

    @Test("confirmEarlyEnd keeps destination when EndSession throws")
    func confirmEarlyEndKeepsDestinationWhenEndSessionThrows() async {
        let session = makeSession()
        mockEndSession.stubbedError = TestError()
        let vm = CountdownViewModel(session: session, clock: FakeTickClock())
        vm.earlyEndTapped()
        await vm.confirmEarlyEnd()
        #expect(vm.destination == .confirmEarlyEnd(session))
    }

    @Test("dismissConfirm clears destination")
    func dismissConfirmClearsDestination() {
        let session = makeSession()
        let vm = CountdownViewModel(session: session, clock: FakeTickClock())
        vm.destination = .confirmEarlyEnd(session)
        vm.dismissConfirm()
        #expect(vm.destination == nil)
    }

    // MARK: - onDisappear

    @Test("onDisappear cancels tick clock")
    func onDisappearCancelsTickClock() {
        let session = makeSession()
        let clock = FakeTickClock()
        let vm = CountdownViewModel(session: session, clock: clock)
        #expect(clock.scheduleCallCount == 1)
        vm.onDisappear()
        #expect(clock.lastToken?.cancelled ?? false)
    }
}

// MARK: - Private Helpers

private extension CountdownViewModelTests {
    func makeSession(duration: Int = 1800, startedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            blocklistId: UUID(),
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(TimeInterval(duration)),
            plannedDurationSeconds: duration,
            appVersion: "test"
        )
    }
}
