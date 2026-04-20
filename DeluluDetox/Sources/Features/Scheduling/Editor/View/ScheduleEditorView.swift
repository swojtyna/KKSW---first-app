import SwiftUI
import SwiftUINavigation

/// Schedule Editor screen — SCH-01 + SCH-02 main UI entry point (D-09, D-10, D-11, D-14).
/// Parent (Plan 05-07 schedule list) pushes this via `navigationDestination`; this view is
/// navigation-agnostic and only reports success via `onSaved` so the parent decides how to dismiss.
struct ScheduleEditorView: View {
    @Bindable var model: ScheduleEditorViewModel

    /// Invoked after `saveTapped()` succeeds so the parent can pop / dismiss.
    var onSaved: () -> Void = {}

    // Display order Monday-first (PL convention); stored as Calendar.weekday values.
    private static let displayOrder: [(label: String, weekday: Int)] = [
        ("Pn", 2), ("Wt", 3), ("Śr", 4), ("Cz", 5), ("Pt", 6), ("Sb", 7), ("Nd", 1),
    ]

    var body: some View {
        Form {
            daysSection
            timeSection
            activitySection
        }
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

    // MARK: - Sections

    @ViewBuilder
    private var daysSection: some View {
        Section("Dni tygodnia") {
            HStack(spacing: 8) {
                ForEach(Self.displayOrder, id: \.weekday) { item in
                    ScheduleDayChip(
                        label: item.label,
                        isSelected: model.daysOfWeek.contains(item.weekday),
                        action: { model.toggleDay(item.weekday) }
                    )
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button("Dni robocze") { model.applyPresetDniRobocze() }
                    .buttonStyle(.bordered)
                Button("Weekend") { model.applyPresetWeekend() }
                    .buttonStyle(.bordered)
                Button("Codziennie") { model.applyPresetCodziennie() }
                    .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var timeSection: some View {
        Section("Przedział czasu") {
            DatePicker("Od", selection: startBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)

            DatePicker("Do", selection: endBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)

            if model.isCrossMidnight {
                Label("Cross-midnight — nocna zmiana, co?", systemImage: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(Theme.crossMidnightHintColor)
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        Section {
            Toggle("Harmonogram aktywny", isOn: $model.enabled)
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        Button {
            Task {
                let didSave = await model.saveTapped()
                if didSave { onSaved() }
            }
        } label: {
            Text(model.isSaving ? "Zapisywanie…" : "Zapisz")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.dayChipFilledBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(!model.canSave)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }

    // MARK: - Bindings

    private var startBinding: Binding<Date> {
        Binding(
            get: {
                var comp = DateComponents()
                comp.hour = model.startHour
                comp.minute = model.startMinute
                return Calendar.current.date(from: comp) ?? Date()
            },
            set: { new in
                let comp = Calendar.current.dateComponents([.hour, .minute], from: new)
                model.startHour = comp.hour ?? 0
                model.startMinute = comp.minute ?? 0
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: {
                var comp = DateComponents()
                comp.hour = model.endHour
                comp.minute = model.endMinute
                return Calendar.current.date(from: comp) ?? Date()
            },
            set: { new in
                let comp = Calendar.current.dateComponents([.hour, .minute], from: new)
                model.endHour = comp.hour ?? 0
                model.endMinute = comp.minute ?? 0
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
}
