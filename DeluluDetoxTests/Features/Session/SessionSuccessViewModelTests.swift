import Foundation
import Testing
@testable import DeluluDetox

@Suite("SessionSuccessViewModel")
@MainActor
struct SessionSuccessViewModelTests {

    @Test("derives durationMinutes from plannedDurationSeconds")
    func initDerivesDurationMinutesFromSessionPlannedDurationSeconds() {
        let vm = SessionSuccessViewModel(session: makeSession(duration: 1800))
        #expect(vm.durationMinutes == 30)
    }

    @Test("uses integer division for fractional seconds")
    func initDerivesDurationMinutesWithIntegerDivisionForFractionalSeconds() {
        let vm = SessionSuccessViewModel(session: makeSession(duration: 1830))
        #expect(vm.durationMinutes == 30)
    }

    @Test("caption is stable and non-empty for same session id")
    func initPicksCaptionFromStablePool() {
        let id = UUID()
        let vm1 = SessionSuccessViewModel(session: makeSession(duration: 1800, id: id))
        let vm2 = SessionSuccessViewModel(session: makeSession(duration: 1800, id: id))
        #expect(vm1.caption == vm2.caption)
        #expect(!vm1.caption.isEmpty)
    }
}

// MARK: - Private Helpers

private extension SessionSuccessViewModelTests {
    func makeSession(duration: Int, id: UUID = UUID()) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(TimeInterval(duration)),
            plannedDurationSeconds: duration,
            appVersion: "test"
        )
    }
}
