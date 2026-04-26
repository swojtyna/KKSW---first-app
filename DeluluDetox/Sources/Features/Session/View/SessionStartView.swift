import SwiftUI
import SwiftUINavigation

struct SessionStartView: View {
    @Bindable var model: SessionStartViewModel

    private static let presets = [15, 30, 60, 90]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                header

                if !model.blocklistHasRecords {
                    emptyBlocklistNudge
                } else {
                    presetChips
                    customWheelSection
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.top, Theme.Spacing.xxl)
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
        .navigationTitle(String(localized: "sessionStartNavigationTitle"))
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.sm) {
                if let hint = summaryHint {
                    Text(hint)
                        .font(.dduFootnote)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                PrimaryButton(
                    title: primaryButtonTitle,
                    systemIcon: model.isStarting ? nil : "bolt.fill"
                ) {
                    Task { await model.startTapped(now: Date()) }
                }
                .opacity(model.canStart ? 1.0 : 0.45)
                .allowsHitTesting(model.canStart)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .alert(
            "commonErrorTitle",
            isPresented: Binding(
                get: {
                    if case .errorAlert = model.destination { return true }
                    return false
                },
                set: { if !$0 { model.clearDestination() } }
            )
        ) {
            Button("commonButtonOk", role: .cancel) { model.clearDestination() }
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
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("sessionStartHeader")
                .font(.dduTitle1)
                .foregroundStyle(Color.textPrimary)
            Text("sessionStartSubheader")
                .font(.dduBody)
                .foregroundStyle(Color.textSecondary)
        }
    }

    @ViewBuilder
    private var emptyBlocklistNudge: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "apps.iphone.badge.plus")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, Theme.Spacing.xs)
            Text("sessionStartEmptyHeading")
                .font(.dduHeadline)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("sessionStartEmptySubheading")
                .font(.dduFootnote)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xxl)
        .background(Color.surfaceElevGrouped, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    @ViewBuilder
    private var presetChips: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("sessionStartPresetsLabel")
                .font(.dduFootnote)
                .kerning(0.4)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Self.presets, id: \.self) { minutes in
                    Button {
                        model.selectPreset(minutes)
                    } label: {
                        DesignChip(text: "\(minutes) min", isActive: model.selectedPresetMinutes == minutes)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) minut preset")
                    .accessibilityAddTraits(model.selectedPresetMinutes == minutes ? [.isSelected] : [])
                }
                Button {
                    model.switchToCustom()
                } label: {
                    DesignChip(text: String(localized: "sessionStartCustomOption"), isActive: model.selectedPresetMinutes == nil, isSoft: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var customWheelSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("sessionStartCustomLabel")
                .font(.dduFootnote)
                .kerning(0.4)
                .foregroundStyle(Color.textSecondary)

            VStack(spacing: 0) {
                Button {
                    model.switchToCustom()
                } label: {
                    HStack {
                        Image(systemName: model.selectedPresetMinutes == nil ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.brandViolet)
                        Text("sessionStartCustomOption2")
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(customDurationLabel)
                            .foregroundStyle(Color.textSecondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .padding(Theme.Spacing.lg)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.selectedPresetMinutes == nil ? [.isSelected] : [])

                if model.selectedPresetMinutes == nil {
                    Divider()
                        .overlay(Color.separator)

                    DatePicker(
                        String(localized: "sessionStartDurationLabel"),
                        selection: customDurationBinding,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(Color.brandViolet)
                    .frame(maxHeight: 180)
                    .padding(.vertical, Theme.Spacing.sm)
                }
            }
            .background(Color.surfaceElevGrouped)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
    }

    // MARK: - Bindings & formatting

    /// DatePicker binds to Date; we convert to/from seconds inside the hour/minute
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

    private var primaryButtonTitle: String {
        if model.isStarting { return String(localized: "sessionStartButtonLoading") }
        if let preset = model.selectedPresetMinutes {
            return String(format: String(localized: "sessionStartButtonPreset"), preset)
        }
        return String(format: String(localized: "sessionStartButtonCustom"), customDurationLabel)
    }

    /// "Will block X items · unlocks at HH:MM" — hidden until both an active
    /// blocklist and a resolved duration are available. The unlock time is a
    /// view-level projection (now + duration); no VM field needed.
    private var summaryHint: String? {
        guard model.blocklistItemCount > 0,
              let duration = model.resolvedDuration
        else { return nil }

        let unlockTime = Date().addingTimeInterval(TimeInterval(duration.seconds))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let unlockLabel = formatter.string(from: unlockTime)

        let count = model.blocklistItemCount
        let itemString = String.localizedStringWithFormat(
            NSLocalizedString("sessionStartItemCountWord", comment: ""),
            Int64(count)
        )
        return String(format: String(localized: "sessionStartSummaryHint"), itemString, unlockLabel)
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
