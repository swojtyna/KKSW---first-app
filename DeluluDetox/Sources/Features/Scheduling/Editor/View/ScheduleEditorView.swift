import SwiftUI
import SwiftUINavigation

/// Schedule Editor screen — SCH-01 + SCH-02 main UI entry point (D-09, D-10, D-11, D-14).
/// Parent (Plan 05-07 schedule list) pushes this via `navigationDestination`; this view is
/// navigation-agnostic and only reports success via `onSaved` so the parent decides how to dismiss.
struct ScheduleEditorView: View {
    @Bindable var model: ScheduleEditorViewModel

    /// Invoked after `saveTapped()` succeeds so the parent can pop / dismiss.
    var onSaved: () -> Void = {}

    /// Monday-first display order (PL convention); stored as Calendar.weekday values.
    private static let displayOrder: [(label: String, weekday: Int)] = [
        ("Pn", 2), ("Wt", 3), ("Śr", 4), ("Cz", 5), ("Pt", 6), ("Sb", 7), ("Nd", 1),
    ]

    private enum TimeField { case start, end }

    @State private var editingField: TimeField = .start

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SectionLabel(text: "Dni")

                GroupedCard {
                    VStack(spacing: Theme.Spacing.md) {
                        HStack(spacing: 6) {
                            ForEach(Self.displayOrder, id: \.weekday) { item in
                                ScheduleDayChip(
                                    label: item.label,
                                    isSelected: model.daysOfWeek.contains(item.weekday),
                                    action: { model.toggleDay(item.weekday) }
                                )
                            }
                        }

                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                model.applyPresetDniRobocze()
                            } label: {
                                DesignChip(text: "Dni robocze", isSoft: true)
                            }
                            .buttonStyle(.plain)

                            Button {
                                model.applyPresetWeekend()
                            } label: {
                                DesignChip(text: "Weekend")
                            }
                            .buttonStyle(.plain)

                            Button {
                                model.applyPresetCodziennie()
                            } label: {
                                DesignChip(text: "Codziennie")
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }

                SectionLabel(text: "Godziny")

                GroupedCard {
                    timeRow(label: "Od", value: formattedTime(startDate), field: .start, isLast: false)
                    timeRow(label: "Do", value: formattedTime(endDate), field: .end, isLast: true)
                }

                GroupedCard {
                    DatePicker(
                        "",
                        selection: editedTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .tint(Color.brandViolet)
                }
                .padding(.top, Theme.Spacing.sm)

                if model.isCrossMidnight {
                    Label("Cross-midnight — nocna zmiana, co?", systemImage: "moon.zzz")
                        .font(.dduFootnote)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, Theme.Spacing.xxxl)
                        .padding(.top, Theme.Spacing.md)
                }

                SectionLabel(text: "Aktywność")

                GroupedCard {
                    GroupedListRow(
                        title: "Harmonogram aktywny",
                        detail: nil,
                        leading: nil,
                        trailing: {
                            DesignToggle(isOn: $model.enabled)
                        },
                        isLast: true
                    )
                }

                Text("Blokady włączą się automatycznie w wybrane dni o \(formattedTime(startDate)).")
                    .font(.dduFootnote)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, Theme.Spacing.xxxl)
                    .padding(.top, Theme.Spacing.lg)

                Spacer().frame(height: 40)
            }
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
        .navigationTitle("Harmonogram")
        .safeAreaInset(edge: .bottom) { saveButton }
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

    // MARK: - Rows

    private func timeRow(label: String, value: String, field: TimeField, isLast: Bool) -> some View {
        Button {
            editingField = field
        } label: {
            GroupedListRow(
                title: label,
                detail: nil,
                leading: nil,
                trailing: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(value)
                            .font(.dduBody.monospacedDigit())
                            .foregroundStyle(editingField == field ? Color.brandViolet : Color.textPrimary)
                        if editingField == field {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.brandViolet)
                        }
                    }
                },
                isLast: isLast
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var saveButton: some View {
        PrimaryButton(title: model.isSaving ? "Zapisywanie…" : "Zapisz") {
            Task {
                let didSave = await model.saveTapped()
                if didSave { onSaved() }
            }
        }
        .opacity(model.canSave ? 1.0 : 0.45)
        .allowsHitTesting(model.canSave)
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.lg)
        .background(.regularMaterial)
    }

    // MARK: - Bindings

    private var startDate: Date {
        var comp = DateComponents()
        comp.hour = model.startHour
        comp.minute = model.startMinute
        return Calendar.current.date(from: comp) ?? Date()
    }

    private var endDate: Date {
        var comp = DateComponents()
        comp.hour = model.endHour
        comp.minute = model.endMinute
        return Calendar.current.date(from: comp) ?? Date()
    }

    private var editedTimeBinding: Binding<Date> {
        Binding(
            get: { editingField == .start ? startDate : endDate },
            set: { newValue in
                let comp = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let hour = comp.hour ?? 0
                let minute = comp.minute ?? 0
                if editingField == .start {
                    model.startHour = hour
                    model.startMinute = minute
                } else {
                    model.endHour = hour
                    model.endMinute = minute
                }
            }
        )
    }

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

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
