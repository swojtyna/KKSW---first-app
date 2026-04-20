import SwiftUI

/// Single day-of-week toggle chip for the Schedule Editor (D-09).
/// Circular badge — filled brandViolet when selected, neutral fill otherwise.
struct ScheduleDayChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.brandViolet : Color(.tertiarySystemFill))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Color.textPrimary)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
