import SwiftUI
import SwiftUINavigation

/// Schedule List screen (SCH-01 entry + SCH-02 row-level quick toggle).
///
/// Shows a single list row per configured `Schedule` (MVP ships with 0 or 1 row;
/// schema supports N per CONTEXT §D-01). Empty state renders sarcastic Polish
/// copy (CONTEXT §Claude's Discretion + D-16) with a primary "Stwórz harmonogram"
/// CTA. Tapping a row pushes the editor from Plan 05-06; toggling the row's
/// trailing Toggle flips enabled via ToggleScheduleUseCase without navigating.
struct ScheduleListView: View {
    @Bindable var model: ScheduleListViewModel

    var body: some View {
        Group {
            if model.schedules.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(model.schedules) { schedule in
                        scheduleRow(schedule)
                    }
                }
            }
        }
        .navigationTitle("Harmonogram")
        .navigationDestination(item: $model.destination.scheduleEditor) { editorModel in
            ScheduleEditorView(model: editorModel) {
                // Editor saved — pop back to list.
                model.clearDestination()
            }
        }
        .alert(
            "Błąd",
            isPresented: errorAlertPresented,
            presenting: errorAlertMessage
        ) { _ in
            Button("OK", role: .cancel) { model.clearDestination() }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Nie masz jeszcze harmonogramu.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Życie samo się nie zablokuje.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Stwórz harmonogram") {
                model.createTapped()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.dayChipFilledBackground)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func scheduleRow(_ schedule: Schedule) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(daysLabel(for: schedule))
                    .font(.headline)
                    .foregroundStyle(schedule.enabled ? .primary : .secondary)
                Text(timeLabel(for: schedule))
                    .font(.subheadline)
                    .foregroundStyle(schedule.enabled ? .secondary : .tertiary)
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { schedule.enabled },
                    set: { newVal in
                        Task { await model.toggleSchedule(scheduleId: schedule.id, enabled: newVal) }
                    }
                )
            )
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { model.editTapped(schedule) }
    }

    // MARK: - Label helpers

    // Display order Monday-first (PL convention); stored as Calendar.weekday values.
    private static let displayOrder: [(label: String, weekday: Int)] = [
        ("Pn", 2), ("Wt", 3), ("Śr", 4), ("Cz", 5), ("Pt", 6), ("Sb", 7), ("Nd", 1),
    ]

    private func daysLabel(for schedule: Schedule) -> String {
        let set = Set(schedule.daysOfWeek)
        let parts = Self.displayOrder.compactMap { set.contains($0.weekday) ? $0.label : nil }
        return parts.joined(separator: ", ")
    }

    private func timeLabel(for schedule: Schedule) -> String {
        let start = String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)
        let end = String(format: "%02d:%02d", schedule.endHour, schedule.endMinute)
        let base = "\(start) – \(end)"
        return schedule.crossesMidnight ? base + " (nocna)" : base
    }

    // MARK: - Alert bindings

    private var errorAlertPresented: Binding<Bool> {
        Binding(
            get: {
                if case .errorAlert = model.destination { return true }
                return false
            },
            set: { if !$0 { model.clearDestination() } }
        )
    }

    private var errorAlertMessage: String? {
        if case .errorAlert(let msg) = model.destination { return msg }
        return nil
    }
}
