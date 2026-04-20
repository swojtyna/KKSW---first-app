import FamilyControls
import SwiftUI
import SwiftUINavigation

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @State private var blockedModel = BlockedViewModel()

    var body: some View {
        contentLayer
            .sheet(item: $model.destination.picker) { session in
                PickerHostView(
                    initialSession: session,
                    onDismiss: { finalSelection in
                        Task { await model.pickerDismissed(committed: finalSelection) }
                    }
                )
            }
            .sheet(item: $model.destination.sessionSuccess) { successModel in
                SessionSuccessView(
                    model: successModel,
                    onDismiss: { model.destination = nil }
                )
            }
            .navigationDestination(item: $model.destination.sessionStart) { startModel in
                sessionStartDestination(startModel: startModel)
            }
            .navigationDestination(item: $model.destination.countdown) { countdownModel in
                CountdownView(model: countdownModel)
            }
            .navigationDestination(item: $model.destination.scheduleList) { listModel in
                scheduleListDestination(listModel: listModel)
            }
            .alert(
                "Coś się popsuło",
                isPresented: Binding(
                    get: {
                        if case .errorAlert = model.destination { return true }
                        return false
                    },
                    set: { if !$0 { model.destination = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.destination = nil }
            } message: {
                if case .errorAlert(let message) = model.destination {
                    Text(message)
                } else {
                    EmptyView()
                }
            }
    }

    // MARK: - Sub-expressions (help the Swift type-checker)

    @ViewBuilder
    private var contentLayer: some View {
        Group {
            if model.snapshot.records.isEmpty {
                emptyHero
            } else {
                BlockedView(model: blockedModel)
            }
        }
        .background(Theme.background)
        .navigationTitle("DeluluDetox")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    model.scheduleListTapped()
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Harmonogram")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.startSessionTapped()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Uruchom sesję")
                .disabled(model.snapshot.records.isEmpty)
            }
        }
        .onAppear {
            // Wire BlockedView's "Zmień wybór" up to the VM that owns the picker Destination.
            // Captured weakly so BlockedView's closure lifetime does not retain HomeViewModel.
            blockedModel.onChangeSelection = { [weak model] in
                model?.chooseAppsTapped()
            }
        }
    }

    /// Blocker 1 (revision 1) — explicit cross-VM bridge.
    ///
    /// SessionStartViewModel signals a successful start by setting its OWN
    /// destination to .countdownHandoff(SessionRecord). The child VM cannot
    /// navigate the parent HomeViewModel; this .onChange observer bridges
    /// the child's state into the parent's destination routing via
    /// HomeViewModel.gotoCountdown(_:). Canonical pattern from Plan 02-06.
    ///
    /// After firing the bridge we clear the child's destination so the
    /// observer is edge-triggered (fires once per handoff).
    @ViewBuilder
    private func sessionStartDestination(startModel: SessionStartViewModel) -> some View {
        SessionStartView(model: startModel)
            .onChange(of: startModel.destination) { _, newValue in
                if case .countdownHandoff(let record) = newValue {
                    model.gotoCountdown(record)
                    startModel.destination = nil
                }
            }
    }

    /// Plan 05-07 — schedule list sub-destination. Extracted into a
    /// `@ViewBuilder` function so HomeView's growing `body` stays under the
    /// Swift type-checker budget (Phase 3 Plan 06 deviation D1 pattern).
    @ViewBuilder
    private func scheduleListDestination(listModel: ScheduleListViewModel) -> some View {
        ScheduleListView(model: listModel)
    }

    @ViewBuilder
    private var emptyHero: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.tertiaryText)
                    .accessibilityLabel("Phone with apps")

                Spacer().frame(height: 16)

                Text("Jeszcze żadnych wrogów")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("Wybierz aplikacje, które kradną Ci czas. Resztą zajmie się DeluluDetox.")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 32)

                Button {
                    model.chooseAppsTapped()
                } label: {
                    Text("Wybierz aplikacje do blokady")
                        .font(.body)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }
}

/// Hosts FamilyActivityPicker inside a .sheet. Needs a local @State because
/// FamilyActivityPicker binds to a plain FamilyActivitySelection Binding; we
/// hand the final value back to HomeViewModel on dismiss.
///
/// Shape validated by Wave 0 spike (02-01-PLAN.md / PickerPresentationSpikeTests).
private struct PickerHostView: View {
    @State private var session: HomeViewModel.PickerSession
    let onDismiss: (FamilyActivitySelection) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        initialSession: HomeViewModel.PickerSession,
        onDismiss: @escaping (FamilyActivitySelection) -> Void
    ) {
        self._session = State(initialValue: initialSession)
        self.onDismiss = onDismiss
    }

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

#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    AppSelectionInjection.register(in: container)
    SessionInjection.register(in: container)
    return NavigationStack {
        HomeView(model: HomeViewModel())
    }
}
