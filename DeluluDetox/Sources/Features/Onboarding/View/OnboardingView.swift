import SwiftUI

struct OnboardingView: View {
    @Bindable var model: OnboardingViewModel

    private let bullets: [(String, String)] = [
        ("Ty wybierasz co blokować.", "Apki, strony, całe kategorie."),
        ("Apple pilnuje — my klikamy.", "Screen Time robi robotę w tle."),
        ("Nic nie leci nigdzie.", "Twoje dane zostają na telefonie."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            heroIcon
                .padding(.top, 60)
                .padding(.bottom, 36)

            Text("Zanim zaczniemy — damy Ci spokój.")
                .font(.dduLargeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.md)

            Text(screenTimeExplanation)
                .font(.dduBody)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)
                .padding(.bottom, 36)

            VStack(spacing: 14) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { index, item in
                    bulletRow(index: index + 1, heading: item.0, sub: item.1)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)

            Spacer(minLength: Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.md) {
                Button {
                    Task { await model.grantAccessTapped() }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        if model.isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Włącz Screen Time")
                                .font(.dduHeadline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brandViolet)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .shadow(color: Color.brandViolet.opacity(0.35), radius: 16, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(model.isRequesting)

                if let errorMessage = model.error {
                    Text(errorMessage)
                        .font(.dduFootnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Odmówione? Ustawienia → Screen Time → Zezwól.")
                        .font(.dduCaption1)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, 40)
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
    }

    private var screenTimeExplanation: AttributedString {
        var lead = AttributedString("Potrzebujemy dostępu do ")
        lead.foregroundColor = .textSecondary

        var emphasis = AttributedString("Screen Time")
        emphasis.foregroundColor = .textPrimary
        emphasis.font = .dduBody.weight(.semibold)

        var tail = AttributedString(". Bez niego umiemy co najwyżej życzyć Ci powodzenia.")
        tail.foregroundColor = .textSecondary

        return lead + emphasis + tail
    }

    private var heroIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.brandViolet, .brandVioletInk],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.brandViolet.opacity(0.4), radius: 40, x: 0, y: 20)

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 66, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 120, height: 120)
    }

    private func bulletRow(index: Int, heading: String, sub: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.brandVioletTint)
                Text("\(index)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandVioletInk)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.dduHeadline)
                    .foregroundStyle(Color.textPrimary)
                Text(sub)
                    .font(.dduFootnote)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
    }
}

#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    return OnboardingView(model: OnboardingViewModel())
}
