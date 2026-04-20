import SwiftUI

/// Single day-of-week toggle chip for the Schedule Editor (D-09).
/// Filled = selected (electric violet), outlined = deselected.
struct ScheduleDayChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(isSelected ? Theme.dayChipFilledBackground : Theme.dayChipBackground)
                .foregroundStyle(isSelected ? Theme.dayChipFilledForeground : Theme.dayChipOutlineForeground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.clear : Theme.dayChipOutlineForeground,
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
