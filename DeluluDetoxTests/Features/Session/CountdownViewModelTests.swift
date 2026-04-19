import XCTest
@testable import DeluluDetox

@MainActor
final class CountdownViewModelTests: XCTestCase {

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

    // MARK: - DI setup

    var mockEndSession: MockEndSessionUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()
        mockEndSession = MockEndSessionUseCase()
        DIContainer.shared.register(EndSessionUseCase.self, scope: .application) { [mockEndSession] _ in mockEndSession! }
    }

    override func tearDown() async throws {
        DIContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSession(duration: Int = 1800, startedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            blocklistId: UUID(),
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(TimeInterval(duration)),
            plannedDurationSeconds: duration,
            appVersion: "test"
        )
    }

    // MARK: - Init / compute

    func testInitSetsRemainingAndProgressFromSession() {
        let session = makeSession()
        let clock = FakeTickClock()
        let vm = CountdownViewModel(
            session: session,
            clock: clock,
            dateProvider: { session.startedAt.addingTimeInterval(600) }
        )
        XCTAssertEqual(vm.remainingSeconds, 1200)
        XCTAssertEqual(vm.progress, 1200.0 / 1800.0, accuracy: 0.001)
    }

    func testInitClampsRemainingToZeroWhenSessionAlreadyExpired() {
        let session = makeSession()
        let clock = FakeTickClock()
        let vm = CountdownViewModel(
            session: session,
            clock: clock,
            dateProvider: { session.plannedEndAt.addingTimeInterval(10) }
        )
        XCTAssertEqual(vm.remainingSeconds, 0)
        XCTAssertEqual(vm.progress, 0.0)
    }

    // MARK: - Tick

    func testTickReducesRemainingByOneSecondPerFire() {
        let session = makeSession()
        let clock = FakeTickClock()
        // Use a class wrapper to avoid Swift 6 "captured var in @Sendable closure" error.
        let nowBox = DateBox(session.startedAt)
        let vm = CountdownViewModel(
            session: session,
            clock: clock,
            dateProvider: { nowBox.value }
        )

        nowBox.value = session.startedAt.addingTimeInterval(1)
        clock.advance()
        XCTAssertEqual(vm.remainingSeconds, 1800 - 1)

        nowBox.value = session.startedAt.addingTimeInterval(2)
        clock.advance()
        XCTAssertEqual(vm.remainingSeconds, 1800 - 2)
    }

    func testTickStopsAtZeroDoesNotGoNegative() {
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
        XCTAssertEqual(vm.remainingSeconds, 0)

        nowBox.value = session.startedAt.addingTimeInterval(4)
        clock.advance()
        XCTAssertEqual(vm.remainingSeconds, 0)
    }

    // MARK: - Early end

    func testEarlyEndTappedSetsConfirmDestination() {
        let session = makeSession()
        let vm = CountdownViewModel(session: session, clock: FakeTickClock())
        vm.earlyEndTapped()
        XCTAssertEqual(vm.destination, .confirmEarlyEnd(session))
    }

    func testConfirmEarlyEndInvokesEndSessionUseCaseWithCancelledByUserOutcome() async {
        let session = makeSession()
        let clock = FakeTickClock()
        let fakeNow = session.startedAt.addingTimeInterval(120)
        let vm = CountdownViewModel(session: session, clock: clock, dateProvider: { fakeNow })
        vm.earlyEndTapped()
        await vm.confirmEarlyEnd()

        XCTAssertEqual(mockEndSession.callCount, 1)
        XCTAssertEqual(mockEndSession.lastOutcome, .cancelledByUser)
        XCTAssertEqual(mockEndSession.lastActualEndAt, fakeNow)
        XCTAssertNil(vm.destination)
    }

    func testConfirmEarlyEndKeepsDestinationWhenEndSessionThrows() async {
        let session = makeSession()
        mockEndSession.stubbedError = TestError()
        let vm = CountdownViewModel(session: session, clock: FakeTickClock())
        vm.earlyEndTapped()
        await vm.confirmEarlyEnd()
        XCTAssertEqual(vm.destination, .confirmEarlyEnd(session))
    }

    func testDismissConfirmClearsDestination() {
        let session = makeSession()
        let vm = CountdownViewModel(session: session, clock: FakeTickClock())
        vm.destination = .confirmEarlyEnd(session)
        vm.dismissConfirm()
        XCTAssertNil(vm.destination)
    }

    // MARK: - onDisappear

    func testOnDisappearCancelsTickClock() {
        let session = makeSession()
        let clock = FakeTickClock()
        let vm = CountdownViewModel(session: session, clock: clock)
        XCTAssertEqual(clock.scheduleCallCount, 1)
        vm.onDisappear()
        XCTAssertTrue(clock.lastToken?.cancelled ?? false)
    }
}
