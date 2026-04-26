import Foundation
import SwiftUI
import FamilyControls
import Testing
@testable import DeluluDetox

@Suite("PickerPresentationSpike — A2 assumption validation")
@MainActor
struct PickerPresentationSpikeTests {

    struct PickerSession: Identifiable, Equatable {
        let id = UUID()
        var selection: FamilyActivitySelection
    }

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

    @Test("PickerHostView compiles with FamilyActivityPicker inside NavigationStack")
    func pickerHostViewCompilesWithFamilyActivityPickerInsideNavigationStack() {
        let view = PickerHostViewSpike(
            session: PickerSession(selection: FamilyActivitySelection()),
            onDismiss: { _ in }
        )
        _ = view.body
    }

    @Test("sheet item binding accepts Identifiable PickerSession")
    func sheetItemBindingAcceptsIdentifiablePickerSession() {
        let host = SheetHostSpike()
        _ = host.body
    }
}
