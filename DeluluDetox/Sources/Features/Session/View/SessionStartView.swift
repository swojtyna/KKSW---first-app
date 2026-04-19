import SwiftUI
import SwiftUINavigation

struct SessionStartView: View {
    @Bindable var model: SessionStartViewModel

    private static let presets = [15, 30, 60, 90]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if !model.blocklistHasRecords {
                    emptyBlocklistNudge
                } else {
                    presetChips
                    customWheelSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(Theme.background)
        .navigationTitle("Nowa sesja")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await model.startTapped(now: Date()) }
            } label: {
                Text(model.isStarting ? "Startuję…" : "Uruchom sesję")
                    .font(.body)
                    .bold()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(!model.canStart)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .alert(
            "Coś się popsuło",
            isPresented: Binding(
                get: {
                    if case .errorAlert = model.destination { return true }
                    return false
                },
                set: { if !$0 { model.clearDestination() } }
            )
        ) {
            Button("OK", role: .cancel) { model.clearDestination() }
        } message: {
            if case .errorAlert(let message) = model.destination {
                Text(message)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            Text("Na ile odłączamy świat?")
                .font(.title2)
                .bold()
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
            Text("Wybierz preset albo ustaw własny czas. Kończy się sam — nie musisz patrzeć.")
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var emptyBlocklistNudge: some View {
        VStack(spacing: 8) {
            Image(systemName: "apps.iphone.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Theme.tertiaryText)
            Text("Najpierw wybierz aplikacje do blokady")
                .font(.body)
                .bold()
                .foregroundStyle(Theme.primaryText)
            Text("Bez tego nie mamy czego blokować.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var presetChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presety")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            HStack(spacing: 12) {
                ForEach(Self.presets, id: \.self) { minutes in
                    chip(for: minutes)
                }
            }
        }
    }

    private func chip(for minutes: Int) -> some View {
        let isSelected = model.selectedPresetMinutes == minutes
        return Button {
            model.selectPreset(minutes)
        } label: {
            Text("\(minutes) min")
                .font(.callout)
                .bold()
                .foregroundStyle(isSelected ? .white : Theme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Theme.accent : Theme.chipBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(minutes) minutes preset")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var customWheelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Albo własny czas")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)

            Button {
                model.switchToCustom()
            } label: {
                HStack {
                    Image(systemName: model.selectedPresetMinutes == nil ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(Theme.accent)
                    Text("Ustaw samodzielnie")
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Text(customDurationLabel)
                        .foregroundStyle(Theme.secondaryText)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if model.selectedPresetMinutes == nil {
                DatePicker(
                    "Czas sesji",
                    selection: customDurationBinding,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxHeight: 160)
            }
        }
    }

    /// The DatePicker binds to a Date; we convert to/from seconds inside the hour/minute
    /// wheel. Reference date is a zeroed-calendar so hour × 3600 + minute × 60 == seconds.
    private var customDurationBinding: Binding<Date> {
        Binding(
            get: {
                let cal = Calendar(identifier: .gregorian)
                let base = cal.startOfDay(for: Date(timeIntervalSince1970: 0))
                return base.addingTimeInterval(TimeInterval(model.customDurationSeconds))
            },
            set: { newValue in
                let cal = Calendar(identifier: .gregorian)
                let comps = cal.dateComponents([.hour, .minute], from: newValue)
                let hours = comps.hour ?? 0
                let minutes = comps.minute ?? 0
                let seconds = hours * 3600 + minutes * 60
                // VM clamps out-of-range values in didSet.
                model.customDurationSeconds = max(seconds, SessionDuration.minSeconds)
            }
        )
    }

    private var customDurationLabel: String {
        let seconds = model.customDurationSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return String(format: "%d h %02d min", hours, minutes)
        }
        return String(format: "%d min", minutes)
    }
}

#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    AppSelectionInjection.register(in: container)
    SessionInjection.register(in: container)
    return NavigationStack {
        SessionStartView(model: SessionStartViewModel())
    }
}
