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
        ScrollView {
            if model.schedules.isEmpty {
                emptyState
                    .frame(minHeight: 520)
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    SectionLabel(text: "Aktywne harmonogramy")
                        .padding(.top, Theme.Spacing.sm)

                    GroupedCard {
                        ForEach(Array(model.schedules.enumerated()), id: \.element.id) { index, schedule in
                            scheduleRow(schedule, isLast: index == model.schedules.count - 1)
                        }
                    }

                    PrimaryButton(title: "Dodaj harmonogram", systemIcon: "plus") {
                        model.createTapped()
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                }
                .padding(.bottom, Theme.Spacing.xxxl)
            }
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
        .navigationTitle("Harmonogram")
        .navigationDestination(item: $model.destination.scheduleEditor) { editorModel in
            ScheduleEditorView(model: editorModel) {
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

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 120, height: 120)
            .padding(.bottom, Theme.Spacing.xxl)

            Text("Nie masz jeszcze harmonogramu.")
                .font(.dduTitle2)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.sm)

            Text("Życie samo się nie zablokuje.")
                .font(.dduBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            PrimaryButton(title: "Stwórz harmonogram", systemIcon: "plus") {
                model.createTapped()
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func scheduleRow(_ schedule: Schedule, isLast: Bool) -> some View {
        Button {
            model.editTapped(schedule)
        } label: {
            GroupedListRow(
                title: daysLabel(for: schedule),
                detail: timeLabel(for: schedule),
                leading: {
                    AnyView(
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .fill(schedule.enabled ? Color.brandVioletTint : Color(.tertiarySystemFill))
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(schedule.enabled ? Color.brandViolet : Color.textTertiary)
                        }
                        .frame(width: 32, height: 32)
                    )
                },
                trailing: {
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
                    .tint(Color.brandViolet)
                },
                isLast: isLast
            )
            .opacity(schedule.enabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Label helpers

    /// Monday-first display order (PL convention); stored as Calendar.weekday values.
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
