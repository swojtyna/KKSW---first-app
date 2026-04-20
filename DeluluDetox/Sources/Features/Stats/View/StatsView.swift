import SwiftUI

/// Stats screen — view-only scaffolding for Phase 6.
///
/// Ports the Hi-Fi design from the design handoff. The view currently
/// renders mock data inline; Phase 6 will introduce StatsViewModel +
/// ObserveStreak / ObserveSessionHistory use cases and replace the
/// hardcoded values below with observed state.
struct StatsView: View {
    // MARK: - Mock data (Phase 6 will move these to StatsViewModel)

    private let markedDays: Set<Int> = [1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
    private let today: Int = 18
    private let leadingEmptyCells: Int = 2
    private let daysInMonth: Int = 30
    private let currentStreak: Int = 7
    private let recordStreak: Int = 12
    private let sessionsThisMonth: Int = 23

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text("Twoje święte wojny")
                    .font(.dduLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)

                HStack(spacing: Theme.Spacing.md) {
                    streakCard(
                        icon: "flame.fill",
                        iconColor: .brandAmber,
                        label: "AKTUALNY",
                        value: "\(currentStreak)",
                        valueColor: .textPrimary,
                        showHot: false
                    )
                    streakCard(
                        icon: nil,
                        iconColor: .clear,
                        label: "REKORD",
                        value: "\(recordStreak)",
                        valueColor: .brandAmber,
                        showHot: true
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)

                calendarCard
                    .padding(.horizontal, Theme.Spacing.lg)

                Text("\(sessionsThisMonth) sesje w tym miesiącu. Ktoś tu rośnie.")
                    .font(.dduFootnote)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.xxxl)

                Spacer().frame(height: Theme.Spacing.xxxl)
            }
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
        .navigationTitle("Statystyki")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Streak card

    private func streakCard(
        icon: String?,
        iconColor: Color,
        label: String,
        value: String,
        valueColor: Color,
        showHot: Bool
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.surfaceElevGrouped

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                        .kerning(0.5)
                }

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(valueColor)

                    Text("dni")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
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

    // MARK: - Calendar card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Kwiecień 2026")
                    .font(.dduHeadline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandViolet)
                        .frame(width: 28, height: 28)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandViolet)
                        .frame(width: 28, height: 28)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["P", "W", "Ś", "C", "P", "S", "N"], id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Theme.Spacing.xs)
                }

                ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day: day)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Color.surfaceElevGrouped)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 8)
    }

    private func dayCell(day: Int) -> some View {
        let isMarked = markedDays.contains(day)
        let isToday = day == today

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isMarked ? Color.brandViolet : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isToday && !isMarked ? Color.brandViolet : .clear, lineWidth: 1.5)
                )

            Text("\(day)")
                .font(.system(size: 13, weight: isToday ? .bold : .medium))
                .foregroundStyle(isMarked ? .white : Color.textPrimary)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("Light") {
    NavigationStack {
        StatsView()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        StatsView()
    }
    .preferredColorScheme(.dark)
}
