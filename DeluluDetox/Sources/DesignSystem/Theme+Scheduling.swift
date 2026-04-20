import SwiftUI

extension Theme {
    // MARK: Day chip (Phase 05 Plan 06)

    /// Fill for selected day-of-week chip — matches `Theme.accent` electric violet #7C3AED.
    static var dayChipFilledBackground: Color { Color(red: 0.486, green: 0.227, blue: 0.929) }
    /// Foreground text for a selected chip.
    static var dayChipFilledForeground: Color { .white }
    /// Foreground text / stroke for an unselected chip.
    static var dayChipOutlineForeground: Color { Color(red: 0.486, green: 0.227, blue: 0.929) }
    /// Background for an unselected chip.
    static var dayChipBackground: Color { Color(.systemGray6) }

    // MARK: Cross-midnight hint

    /// Subtle secondary color for the "Cross-midnight" marker (D-10).
    static var crossMidnightHintColor: Color { .secondary }
}
