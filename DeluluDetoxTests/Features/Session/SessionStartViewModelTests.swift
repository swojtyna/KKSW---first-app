import Foundation
import Combine
import Testing
@testable import DeluluDetox

@Suite(.serialized)
@MainActor
final class SessionStartViewModelTests {

    struct TestError: Error {}

    let mockStart: MockStartSessionUseCase
    let mockObserveActive: MockObserveActiveSessionUseCase
    let mockObserveBlocklist: MockObserveBlocklistUseCase

    init() {
        DIContainer.shared.reset()

        mockStart = MockStartSessionUseCase()
        mockObserveActive = MockObserveActiveSessionUseCase()
        mockObserveBlocklist = MockObserveBlocklistUseCase()

        DIContainer.shared.register(StartSessionUseCase.self, scope: .application) { [mockStart] _ in mockStart }
        DIContainer.shared.register(ObserveActiveSessionUseCase.self, scope: .application) { [mockObserveActive] _ in mockObserveActive }
        DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .application) { [mockObserveBlocklist] _ in mockObserveBlocklist }
    }

    // MARK: - Initial state

    @Test("initial state has preset 30 minutes and nil destination")
    func initialStateHasPreset30MinutesAndCustom30MinutesAndNilDestination() {
        let vm = SessionStartViewModel()
        #expect(vm.selectedPresetMinutes == 30)
        #expect(vm.customDurationSeconds == 1800)
        #expect(vm.destination == nil)
        #expect(!vm.isStarting)
    }

    // MARK: - Preset / custom toggles

    @Test("selectPreset updates selectedPreset and keeps custom untouched")
    func selectPresetUpdatesSelectedPresetAndKeepsCustomUntouched() {
        let vm = SessionStartViewModel()
        vm.customDurationSeconds = 900
        vm.selectPreset(60)
        #expect(vm.selectedPresetMinutes == 60)
        #expect(vm.customDurationSeconds == 900)
    }

    @Test("switchToCustom clears selectedPreset")
    func switchToCustomClearsSelectedPreset() {
        let vm = SessionStartViewModel()
        vm.switchToCustom()
        #expect(vm.selectedPresetMinutes == nil)
    }

    // MARK: - resolvedDuration

    @Test("resolvedDuration reads preset first")
    func resolvedDurationReadsPresetFirst() {
        let vm = SessionStartViewModel()
        vm.selectPreset(30)
        vm.customDurationSeconds = 900
        #expect(vm.resolvedDuration?.seconds == 1800)
    }

    @Test("resolvedDuration reads custom when no preset selected")
    func resolvedDurationReadsCustomWhenNoPresetSelected() {
        let vm = SessionStartViewModel()
        vm.switchToCustom()
        vm.customDurationSeconds = 3600
        #expect(vm.resolvedDuration?.seconds == 3600)
    }

    @Test("resolvedDuration clamps custom below min")
    func resolvedDurationClampsCustomBelowMin() {
        let vm = SessionStartViewModel()
        vm.switchToCustom()
        vm.customDurationSeconds = 299
        #expect(vm.customDurationSeconds == SessionDuration.minSeconds)
        #expect(vm.resolvedDuration?.seconds == SessionDuration.minSeconds)
    }

    // MARK: - canStart gate

    @Test("canStart is false when blocklist is empty")
    func canStartIsFalseWhenBlocklistIsEmpty() async {
        let vm = SessionStartViewModel()
        mockObserveBlocklist.subject.send(Blocklist.empty())
        await yield()
        #expect(!vm.canStart)
    }

    @Test("canStart is true when blocklist has records and duration valid")
    func canStartIsTrueWhenBlocklistHasRecordsAndDurationValid() async {
        let vm = SessionStartViewModel()
        var list = Blocklist.empty()
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()
        #expect(vm.canStart)
    }

    // MARK: - startTapped gates + success + failure

    @Test("startTapped routes to sessionInProgress when active exists")
    func startTappedRoutesToSessionInProgressWhenActiveExists() async {
        let vm = SessionStartViewModel()
        let active = makeActiveRecord()
        mockObserveActive.subject.send(active)
        await yield()

        await vm.startTapped(now: Date())

        #expect(vm.destination == .sessionInProgress(active))
        #expect(mockStart.callCount == 0)
    }

    @Test("startTapped calls start use case with resolved duration and blocklist id")
    func startTappedCallsStartSessionUseCaseWithResolvedDurationAndBlocklistId() async {
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

        #expect(mockStart.callCount == 1)
        #expect(mockStart.lastBlocklistId == blocklistId)
        #expect(mockStart.lastDuration?.seconds == 1800)
        #expect(mockStart.lastNow == now)
    }

    @Test("startTapped success routes destination to countdownHandoff")
    func startTappedSuccessRoutesDestinationToCountdownHandoff() async {
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
        #expect(vm.destination == .countdownHandoff(stubbed))
    }

    @Test("startTapped failure routes destination to errorAlert with Polish copy")
    func startTappedFailureRoutesDestinationToErrorAlertWithPolishCopy() async {
        let vm = SessionStartViewModel()
        var list = Blocklist.empty()
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()

        mockStart.stubbedError = TestError()
        await vm.startTapped(now: Date())

        #expect(
            vm.destination == .errorAlert("Coś poszło nie tak. Timer nie wystartował — spróbuj jeszcze raz.")
        )
    }

    @Test("startTapped is no-op while isStarting is true")
    func startTappedIsNoOpWhileIsStartingTrue() async {
        let vm = SessionStartViewModel()
        var list = Blocklist.empty()
        list.records = [
            TokenRecord(id: UUID(), kind: .application, encodedToken: Data([0x01]), lastSeenAt: Date()),
        ]
        mockObserveBlocklist.subject.send(list)
        await yield()

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

        async let first: Void = vm.startTapped(now: Date())
        await yield()
        async let second: Void = vm.startTapped(now: Date())
        await yield()

        gate.continuation.yield()
        gate.continuation.finish()

        _ = await first
        _ = await second

        #expect(mockStart.callCount == 1)
    }

    @Test("clearDestination resets to nil")
    func clearDestinationResetsToNil() {
        let vm = SessionStartViewModel()
        vm.destination = .errorAlert("x")
        vm.clearDestination()
        #expect(vm.destination == nil)
    }
}

// MARK: - Private Helpers

private extension SessionStartViewModelTests {
    func makeActiveRecord(now: Date = Date()) -> SessionRecord {
        SessionRecord(
            blocklistId: UUID(),
            startedAt: now,
            plannedEndAt: now.addingTimeInterval(1800),
            plannedDurationSeconds: 1800,
            appVersion: "test"
        )
    }

    func yield() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }
}
