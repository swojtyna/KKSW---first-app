import XCTest
@testable import DeluluDetox

@MainActor
final class SessionSuccessViewModelTests: XCTestCase {
    // NOTE: SuccessShownFlag UserDefaults-setup was removed in revision 1. Persistence
    // of the 'success-shown' flag is now covered by SuccessShownUseCasesTests (Plan 03-03 Task 2),
    // not by this VM test. This VM is a pure value-derivation test — no UserDefaults surface.

    private func makeSession(duration: Int, id: UUID = UUID()) -> SessionRecord {
        SessionRecord(
            id: id,
            blocklistId: UUID(),
            startedAt: Date(),
            plannedEndAt: Date().addingTimeInterval(TimeInterval(duration)),
            plannedDurationSeconds: duration,
            appVersion: "test"
        )
    }

    func testInitDerivesDurationMinutesFromSessionPlannedDurationSeconds() {
        let vm = SessionSuccessViewModel(session: makeSession(duration: 1800))
        XCTAssertEqual(vm.durationMinutes, 30)
    }

    func testInitDerivesDurationMinutesWithIntegerDivisionForFractionalSeconds() {
        let vm = SessionSuccessViewModel(session: makeSession(duration: 1830))
        XCTAssertEqual(vm.durationMinutes, 30)    // 1830 / 60 = 30
    }

    func testInitPicksCaptionFromStablePool() {
        let id = UUID()
        let vm1 = SessionSuccessViewModel(session: makeSession(duration: 1800, id: id))
        let vm2 = SessionSuccessViewModel(session: makeSession(duration: 1800, id: id))
        XCTAssertEqual(vm1.caption, vm2.caption)
        XCTAssertFalse(vm1.caption.isEmpty)
    }
}
