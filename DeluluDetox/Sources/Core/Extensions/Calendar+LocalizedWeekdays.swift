import Foundation

extension Calendar {
    /// Weekday display order Monday-first with locale-aware labels.
    /// Returns 7 tuples: Mon(weekday=2), Tue(3), …, Sat(7), Sun(1).
    /// Always Monday-first to match the hardcoded Monday-first encoding
    /// in ComputeStatsUseCase and StatsViewModel.
    var localizedWeekdayDisplayOrder: [(label: String, weekday: Int)] {
        // veryShortStandaloneWeekdaySymbols[0]=Sun(weekday=1), [1]=Mon(weekday=2), …, [6]=Sat(weekday=7)
        let symbols = veryShortStandaloneWeekdaySymbols
        return (0..<7).map { offset in
            let index = (1 + offset) % 7   // start at Monday (index 1), end with Sunday (index 0)
            return (label: symbols[index], weekday: index + 1)
        }
    }
}
