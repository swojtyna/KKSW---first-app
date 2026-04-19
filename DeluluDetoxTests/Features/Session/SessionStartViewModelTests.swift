import XCTest
import Combine
@testable import DeluluDetox

@MainActor
final class SessionStartViewModelTests: XCTestCase {

    struct TestError: Error {}

    var mockStart: MockStartSessionUseCase!
    var mockObserveActive: MockObserveActiveSessionUseCase!
    var mockObserveBlocklist: MockObserveBlocklistUseCase!

    override func setUp() async throws {
        try await super.setUp()
        DIContainer.shared.reset()

        mockStart = MockStartSessionUseCase()
        mockObserveActive = MockObserveActiveSessionUseCase()
        mockObserveBlocklist = MockObserveBlocklistUseCase()

        DIContainer.shared.register(StartSessionUseCase.self, scope: .application) { [mockStart] _ in mockStart! }
        DIContainer.shared.register(ObserveActiveSessionUseCase.self, scope: .application) { [mockObserveActive] _ in mockObserveActive! }
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .application) { [mockObserveBlocklist] _ in mockObserveBlocklist! }
    }

    override func tearDown() async throws {
        DIContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateHasPreset30MinutesAndCustom30MinutesAndNilDestination() {
        let vm = SessionStartViewModel()
        XCTAssertEqual(vm.selectedPresetMinutes, 30)
        XCTAssertEqual(vm.customDurationSeconds, 1800)
        XCTAssertNil(vm.destination)
        XCTAssertFalse(vm.isStarting)
    }

    // MARK: - Preset / custom toggles

    func testSelectPresetUpdatesSelectedPresetAndKeepsCustomUntouched() {
        let vm = SessionStartViewModel()
        vm.customDurationSeconds = 900      // 15 min stored on custom
        vm.selectPreset(60)
        XCTAssertEqual(vm.selectedPresetMinutes, 60)
        XCTAssertEqual(vm.customDurationSeconds, 900)
    }

    func testSwitchToCustomClearsSelectedPreset() {
        let vm = SessionStartViewModel()
        vm.switchToCustom()
        XCTAssertNil(vm.selectedPresetMinutes)
    }

    // MARK: - resolvedDuration

    func testResolvedDurationReadsPresetFirst() {
        let vm = SessionStartViewModel()
        vm.selectPreset(30)
        vm.customDurationSeconds = 900
        XCTAssertEqual(vm.resolvedDuration?.seconds, 1800)
    }

    func testResolvedDurationReadsCustomWhenNoPresetSelected() {
        let vm = SessionStartViewModel()
        vm.switchToCustom()
        vm.customDurationSeconds = 3600
        XCTAssertEqual(vm.resolvedDuration?.seconds, 3600)
    }

    func testResolvedDurationClampsCustomBelowMin() {
        let vm = SessionStartViewModel()
        vm.switchToCustom()
        vm.customDurationSeconds = 299    // below 5 min
        XCTAssertEqual(vm.customDurationSeconds, SessionDuration.minSeconds)
        XCTAssertEqual(vm.resolvedDuration?.seconds, SessionDuration.minSeconds)
    }

    // MARK: - canStart gate

    func testCanStartIsFalseWhenBlocklistIsEmpty() async {
        let vm = SessionStartViewModel()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        await yield()
        XCTAssertFalse(vm.canStart)
    }

    func testCanStartIsTrueWhenBlocklistHasRecordsAndDurationValid() async {
        let vm = SessionStartViewModel()
        var list = Blocklist.empty()
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()
        XCTAssertTrue(vm.canStart)
    }

    // MARK: - startTapped gates + success + failure

    func testStartTappedRoutesToSessionInProgressWhenActiveExists() async {
        let vm = SessionStartViewModel()
        let active = makeActiveRecord()
        mockObserveActive.subject.send(active)
        await yield()

        await vm.startTapped(now: Date())

        XCTAssertEqual(vm.destination, .sessionInProgress(active))
        XCTAssertEqual(mockStart.callCount, 0)
    }

    func testStartTappedCallsStartSessionUseCaseWithResolvedDurationAndBlocklistId() async {
        let vm = SessionStartViewModel()
        let blocklistId = UUID()
        var list = Blocklist.empty(id: blocklistId)
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()

        vm.selectPreset(30)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        mockStart.stubbedResult = SessionRecord(
            blocklistId: blocklistId,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )

        await vm.startTapped(now: now)

        XCTAssertEqual(mockStart.callCount, 1)
        XCTAssertEqual(mockStart.lastBlocklistId, blocklistId)
        XCTAssertEqual(mockStart.lastDuration?.seconds, 1800)
        XCTAssertEqual(mockStart.lastNow, now)
    }

    func testStartTappedSuccessRoutesDestinationToCountdownHandoff() async {
        let vm = SessionStartViewModel()
        let blocklistId = UUID()
        var list = Blocklist.empty(id: blocklistId)
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()

        let now = Date()
        let stubbed = SessionRecord(
            blocklistId: blocklistId,
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
        mockStart.stubbedResult = stubbed

        await vm.startTapped(now: now)
        XCTAssertEqual(vm.destination, .countdownHandoff(stubbed))
    }

    func testStartTappedFailureRoutesDestinationToErrorAlertWithPolishCopy() async {
        let vm = SessionStartViewModel()
        var list = Blocklist.empty()
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()

        mockStart.stubbedError = TestError()
        await vm.startTapped(now: Date())

        XCTAssertEqual(
            vm.destination,
            .errorAlert("Coś poszło nie tak. Timer nie wystartował — spróbuj jeszcze raz.")
        )
    }

    func testStartTappedIsNoOpWhileIsStartingTrue() async {
        // Re-entry guard: a second startTapped() call while the first is in flight
        // must NOT produce a second StartSessionUseCase invocation. Correctness
        // invariant — duplicate in-flight starts would create two SessionRecords.
        let vm = SessionStartViewModel()
        var list = Blocklist.empty()
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()

        // Gate the mock's return on an external signal so the first call stays in-flight.
        let gate = AsyncStream<Void>.makeStream()
        mockStart.beforeReturn = {
            await gate.stream.first { _ in true }
        }
        mockStart.stubbedResult = SessionRecord(
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )

        // Fire two overlapping start taps. The second MUST short-circuit via the
        // isStarting guard before the first completes.
        async let first: Void = vm.startTapped(now: Date())
        await yield()
        async let second: Void = vm.startTapped(now: Date())
        await yield()

        // Release the first call.
        gate.continuation.yield()
        gate.continuation.finish()

        _ = await first
        _ = await second

        XCTAssertEqual(mockStart.callCount, 1)
    }

    func testClearDestinationResetsToNil() {
        let vm = SessionStartViewModel()
        vm.destination = .errorAlert("x")
        vm.clearDestination()
        XCTAssertNil(vm.destination)
    }

    // MARK: - Helpers

    private func makeActiveRecord(now: Date = Date()) -> SessionRecord {
        SessionRecord(
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }

    private func yield() async {
        // Three hops to drain Combine `.receive(on: DispatchQueue.main)` + defer.
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }
}
