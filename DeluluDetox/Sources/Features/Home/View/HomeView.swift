import FamilyControls
import SwiftUI
import SwiftUINavigation

struct HomeView: View {
    @Bindable var model: HomeViewModel
    @State private var blockedModel = BlockedViewModel()
    @State private var scheduleListModel = ScheduleListViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        tabContent
            .safeAreaInset(edge: .bottom) {
                DesignTabBar(activeIndex: selectedTab) { index in
                    selectedTab = index
                }
                .padding(.bottom, Theme.Spacing.xs)
            }
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

    // MARK: - Tab content

    /// Swaps the active tab's view inline. Each tab owns its state via @State
    /// in HomeView so switching back preserves scroll position / edited fields.
    /// Navigation pushes that originate INSIDE a tab (e.g., tapping a schedule
    /// row to open the editor) still resolve through the parent NavigationStack
    /// provided by AppRootView.
    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 1:
                BlockedView(model: blockedModel)
            case 2:
                ScheduleListView(model: scheduleListModel)
            case 3:
                StatsView()
            default:
                dzisiajContent
            }
        }
        .background(Color.surfaceGrouped)
        .onAppear {
            // Wire BlockedView's CTAs up to the VM that owns the picker /
            // session destinations. Captured weakly so BlockedView's closure
            // lifetime does not retain HomeViewModel.
            blockedModel.onChangeSelection = { [weak model] in
                model?.chooseAppsTapped()
            }
            blockedModel.onStartSession = { [weak model] in
                model?.startSessionTapped()
            }
        }
    }

    /// "Dzisiaj" tab content — Phase 6 will replace this with a streak
    /// dashboard. For now mirrors the prior Home body: empty hero when the
    /// blocklist has no records, else the list itself.
    @ViewBuilder
    private var dzisiajContent: some View {
        if model.snapshot.records.isEmpty {
            emptyHero
                .navigationTitle("DeluluDetox")
                .navigationBarTitleDisplayMode(.large)
        } else {
            BlockedView(model: blockedModel)
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

    @ViewBuilder
    private var emptyHero: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.brandViolet, .brandVioletInk],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.brandViolet.opacity(0.4), radius: 40, x: 0, y: 20)

                Image(systemName: "apps.iphone")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 120, height: 120)
            .padding(.bottom, Theme.Spacing.xxl)

            Text("Jeszcze żadnych wrogów.")
                .font(.dduLargeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.sm)

            Text("Wybierz aplikacje, które kradną Ci czas. Resztą zajmie się DeluluDetox.")
                .font(.dduBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)

            Spacer()

            PrimaryButton(title: "Wybierz aplikacje do blokady", systemIcon: "plus") {
                model.chooseAppsTapped()
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, 40)
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
