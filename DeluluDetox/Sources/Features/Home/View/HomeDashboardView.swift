import SwiftUI

/// "Dzisiaj" tab landing — VM-driven for the stats section (Phase 6 Plan 05).
///
/// Ports the Hi-Fi dashboard from the design handoff (streak hero + quick
/// stats + next-block card + Szybka sesja CTA). Stats-related data is fed by
/// `HomeStatsCardViewModel`; the greeting + next-block card remain mock in
/// MVP (out of Phase 6 scope — they are not stats bindings).
///
/// Tapping the streak hero forwards up via `onStatsCardTap` (HomeView routes
/// that to `HomeViewModel.statsCardTapped()` → `.stats` destination). The
/// "Szybka sesja" button forwards via `onQuickSessionTap`.
struct HomeDashboardView: View {
    @Bindable var statsCard: HomeStatsCardViewModel
    let onQuickSessionTap: () -> Void
    let onStatsCardTap: () -> Void

    // KEPT as mock (out-of-scope for Phase 6 — greeting is not a stats binding).
    private let greetingName: String = "mistrzu"
    private let greetingSubtitle: String = "Sobota, 18 kwietnia — dzień 7."

    // KEPT as mock (next-block card is Phase 5 territory; Plan 05 leaves this intact
    // — not part of GAM-01/02 scope).
    private let nextBlockTitle: String = "Dni robocze · 9–17"
    private let nextBlockSubtitle: String = "Aktywny · 12 blokad"
    @State private var nextBlockEnabled: Bool = true

    private var weekdayDisplayLabels: [String] {
        Calendar.current.localizedWeekdayDisplayOrder.map { $0.label }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(String(format: String(localized: "homeDashboardGreeting"), greetingName))
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
                    // Phase 6 D-10: branch on broken-streak copy.
                    if let shame = statsCard.brokenStreakCopy {
                        brokenStreakHeroCard(shame: shame)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .contentShape(Rectangle())
                            .onTapGesture { onStatsCardTap() }
                    } else {
                        regularStreakHeroCard
                            .padding(.horizontal, Theme.Spacing.lg)
                            .contentShape(Rectangle())
                            .onTapGesture { onStatsCardTap() }
                    }

                    HStack(spacing: 10) {
                        quickStat(label: String(localized: "homeDashboardCompletedLabel"), value: "\(statsCard.stats.totalCount)", tint: Color.textPrimary)
                        quickStat(label: String(localized: "homeDashboardRecordLabel"), value: "\(statsCard.stats.longestStreak)", tint: Color.brandAmber, showHot: true)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    nextBlockCard
                        .padding(.horizontal, Theme.Spacing.lg)

                    PrimaryButton(title: String(localized: "homeDashboardButtonQuickSession"), systemIcon: "bolt.fill") {
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

    // MARK: - Regular streak hero (violet flame)

    private var regularStreakHeroCard: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [.brandViolet, .brandVioletInk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("homeDashboardStreakLabel")
                            .font(.dduFootnote)
                            .kerning(0.5)
                            .foregroundStyle(.white.opacity(0.8))

                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                            Text("\(statsCard.stats.currentStreak)")
                                .font(.system(size: 54, weight: .bold))
                                .foregroundStyle(.white)

                            Text("commonDaysUnit")
                                .font(.dduTitle3)
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Text("homeDashboardMotivation")
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
                    ForEach(Array(statsCard.stats.last7DaysFlags.enumerated()), id: \.offset) { index, isOn in
                        VStack(spacing: 2) {
                            Text(weekdayDisplayLabels[safe: index] ?? "")
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
                                .stroke(index == statsCard.stats.todayWeekdayIndex ? Color.white : .clear, lineWidth: 1.5)
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

    // MARK: - Broken streak hero (gray flame — D-10)

    private func brokenStreakHeroCard(shame: String) -> some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("homeDashboardBrokenStreakLabel")
                    .font(.dduFootnote).kerning(0.5)
                    .foregroundStyle(.white.opacity(0.8))
                Text("homeDashboardBrokenStreakZero")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                Text(shame)
                    .font(.dduCallout)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.xl)

            ZStack {
                Circle().fill(Color.gray.opacity(0.5))
                Image(systemName: "flame")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 48, height: 48)
            .padding(Theme.Spacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
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
                Text("homeDashboardHotBadge")
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

    // MARK: - Next-block card (kept mock — Phase 5 territory)

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

// MARK: - Collection safe subscript (defensive against malformed last7DaysFlags)

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Light") {
    HomeDashboardView(
        statsCard: HomeStatsCardViewModel(),
        onQuickSessionTap: {},
        onStatsCardTap: {}
    )
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeDashboardView(
        statsCard: HomeStatsCardViewModel(),
        onQuickSessionTap: {},
        onStatsCardTap: {}
    )
    .preferredColorScheme(.dark)
}
