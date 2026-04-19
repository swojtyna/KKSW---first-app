import XCTest
import SwiftUI
import FamilyControls
@testable import DeluluDetox

/// Wave 0 spike — A2 assumption validation (see 02-RESEARCH.md §Assumptions Log).
///
/// Validates at compile time that FamilyActivityPicker can be hosted inside a
/// custom NavigationStack and presented via `.sheet(item:)` with an Identifiable
/// session wrapper. Presentation behavior on device is verified by the Plan 07
/// human-verify checkpoint — this spike guarantees the code shape compiles and
/// the types line up under Swift 6.2 strict concurrency.
///
/// Rationale: Plan 06 will ship the real PickerHostView inside HomeView.swift.
/// If A2 is wrong, Apple's FamilyActivityPicker would reject the outer
/// NavigationStack and Plan 06 would have to fall back to the
/// `.familyActivityPicker(isPresented:selection:)` modifier — a fallback that
/// breaks the Destination-enum pattern. Better to know in Wave 0.
@MainActor
final class PickerPresentationSpikeTests: XCTestCase {

    // Mirror of HomeViewModel.PickerSession that Plan 06 will ship.
    struct PickerSession: Identifiable, Equatable {
        let id = UUID()
        var selection: FamilyActivitySelection
    }

    // Mirror of Plan 06's PickerHostView — kept fileprivate to the test module
    // to prove the exact shape compiles without touching Sources/.
    private struct PickerHostViewSpike: View {
        @State var session: PickerSession
        let onDismiss: (FamilyActivitySelection) -> Void
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                FamilyActivityPicker(selection: $session.selection)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Gotowe") {
                                onDismiss(session.selection)
                                dismiss()
                            }
                        }
                    }
            }
        }
    }

    private struct SheetHostSpike: View {
        @State private var activeSession: PickerSession?

        var body: some View {
            Color.clear
                .sheet(item: $activeSession) { session in
                    PickerHostViewSpike(
                        session: session,
                        onDismiss: { _ in activeSession = nil }
                    )
                }
        }
    }

    func testPickerHostViewCompilesWithFamilyActivityPickerInsideNavigationStack() {
        let view = PickerHostViewSpike(
            session: PickerSession(selection: FamilyActivitySelection()),
            onDismiss: { _ in }
        )
        // Force body resolution to flush any compile-time diagnostics that only
        // surface during View graph evaluation.
        _ = view.body
    }

    func testSheetItemBindingAcceptsIdentifiablePickerSession() {
        let host = SheetHostSpike()
        _ = host.body
    }
}
