import SwiftUI

/// Stats screen — VM-driven per Phase 6 Plan 05 (H7).
/// All dynamic state lives on `StatsViewModel`; weekday labels use
/// Calendar.current for locale-aware symbols (always Monday-first to match
/// the hardcoded Monday-first encoding in StatsViewModel).
struct StatsView: View {
    @Bindable var model: StatsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text("statsHeading")
                    .font(.dduLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.sm)

                HStack(spacing: Theme.Spacing.md) {
                    streakCard(
                        icon: "flame.fill",
                        iconColor: .brandAmber,
                        label: String(localized: "statsCurrentLabel"),
                        value: "\(model.stats.currentStreak)",
                        valueColor: .textPrimary,
                        showHot: false
                    )
                    streakCard(
                        icon: nil,
                        iconColor: .clear,
                        label: String(localized: "statsRecordLabel"),
                        value: "\(model.stats.longestStreak)",
                        valueColor: .brandAmber,
                        showHot: true
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)

                calendarCard
                    .padding(.horizontal, Theme.Spacing.lg)

                Text(String(format: String(localized: "statsTotalSessions"), Int64(model.stats.totalCount)))
                    .font(.dduFootnote)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.xxxl)

                Spacer().frame(height: Theme.Spacing.xxxl)
            }
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
        .navigationTitle(String(localized: "statsNavigationTitle"))
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

                    Text("commonDaysUnit")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)

            if showHot {
                Text("statsHotBadge")
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

    // MARK: - Calendar card — VM-driven

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.displayedMonthFormatted)
                    .font(.dduHeadline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Button(action: { model.prevMonthTapped() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandViolet)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    Button(action: { model.nextMonthTapped() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandViolet)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Calendar.current.localizedWeekdayDisplayOrder, id: \.weekday) { day in
                    Text(day.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Theme.Spacing.xs)
                }

                // Leading empty cells before day 1. String IDs avoid colliding with the Int day IDs below.
                ForEach((0..<model.leadingEmptyCells).map { "empty-\($0)" }, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }

                ForEach(1...max(model.daysInMonth, 1), id: \.self) { day in
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
        let date = model.date(forDayOfMonth: day) ?? Date()
        let isMarked = model.isMarked(day: date)
        let isToday = model.isToday(day: date)

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
        StatsView(model: StatsViewModel())
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        StatsView(model: StatsViewModel())
    }
    .preferredColorScheme(.dark)
}
