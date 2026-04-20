import SwiftUI

/// "Dzisiaj" tab landing — view-only scaffolding for Phase 6.
///
/// Ports the Hi-Fi dashboard from the design handoff (streak hero + quick
/// stats + next-block card + Szybka sesja CTA). Every metric rendered
/// here is mock data; Phase 6 will introduce HomeDashboardViewModel backed
/// by ObserveStreak / ObserveSessionHistory / ObserveSchedule and replace
/// the hardcoded values.
///
/// The "Szybka sesja" button forwards up to the parent (HomeView) via
/// `onQuickSessionTap` so this view stays view-model-free.
struct HomeDashboardView: View {
    let onQuickSessionTap: () -> Void

    // MARK: - Mock data (Phase 6 will move these to a dashboard VM)

    private let greetingName: String = "mistrzu"
    private let greetingSubtitle: String = "Sobota, 18 kwietnia — dzień 7."
    private let streakDays: Int = 7
    private let dayLabels: [String] = ["Pn", "Wt", "Śr", "Cz", "Pt", "Sb", "Nd"]
    private let streakFlags: [Bool] = [true, true, true, true, true, true, true]
    private let todayIndex: Int = 6
    private let completedCount: Int = 23
    private let recordCount: Int = 12
    private let nextBlockTitle: String = "Dni robocze · 9–17"
    private let nextBlockSubtitle: String = "Aktywny · 12 blokad"
    @State private var nextBlockEnabled: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Cześć, \(greetingName).")
                        .font(.dduLargeTitle)
                        .foregroundStyle(Color.textPrimary)
                    Text(greetingSubtitle)
                        .font(.dduSubheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.md)

                VStack(spacing: 14) {
                    streakHeroCard
                        .padding(.horizontal, Theme.Spacing.lg)

                    HStack(spacing: 10) {
                        quickStat(label: "UKOŃCZONYCH", value: "\(completedCount)", tint: Color.textPrimary)
                        quickStat(label: "REKORD", value: "\(recordCount)", tint: Color.brandAmber, showHot: true)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    nextBlockCard
                        .padding(.horizontal, Theme.Spacing.lg)

                    PrimaryButton(title: "Szybka sesja", systemIcon: "bolt.fill") {
                        onQuickSessionTap()
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.xs)
                }
                .padding(.bottom, Theme.Spacing.xxxl)
            }
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
    }

    // MARK: - Streak hero

    private var streakHeroCard: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [.brandViolet, .brandVioletInk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AKTUALNY STREAK")
                            .font(.dduFootnote)
                            .kerning(0.5)
                            .foregroundStyle(.white.opacity(0.8))

                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                            Text("\(streakDays)")
                                .font(.system(size: 54, weight: .bold))
                                .foregroundStyle(.white)

                            Text("dni")
                                .font(.dduTitle3)
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Text("Dziś też nie zawal.")
                            .font(.dduCallout)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.brandAmber)
                            .shadow(color: Color.brandAmber.opacity(0.4), radius: 16, x: 0, y: 6)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)
                }

                HStack(spacing: 6) {
                    ForEach(Array(streakFlags.enumerated()), id: \.offset) { index, isOn in
                        VStack(spacing: 2) {
                            Text(dayLabels[index])
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(.white.opacity(0.75))

                            if isOn {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .fill(isOn ? .white.opacity(0.25) : .white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .stroke(index == todayIndex ? Color.white : .clear, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.top, 18)
            }
            .padding(Theme.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .shadow(color: Color.brandViolet.opacity(0.3), radius: 40, x: 0, y: 16)
    }

    // MARK: - Quick stat card

    private func quickStat(label: String, value: String, tint: Color, showHot: Bool = false) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.surfaceElevGrouped

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .kerning(0.5)

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)

            if showHot {
                Text("HOT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.brandAmberInk)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Color.brandAmberTint, in: RoundedRectangle(cornerRadius: Theme.Radius.sm - 2, style: .continuous))
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 8)
    }

    // MARK: - Next-block card

    private var nextBlockCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Color.brandVioletTint)
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.brandViolet)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(nextBlockTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(nextBlockSubtitle)
                    .font(.dduFootnote)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            DesignToggle(isOn: $nextBlockEnabled)
        }
        .padding(14)
        .background(Color.surfaceElevGrouped)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 8)
    }
}

#Preview("Light") {
    HomeDashboardView(onQuickSessionTap: {})
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeDashboardView(onQuickSessionTap: {})
        .preferredColorScheme(.dark)
}
