import SwiftUI

struct OnboardingView: View {
    @Bindable var model: OnboardingViewModel

    private let bulletKeys: [(LocalizedStringKey, LocalizedStringKey)] = [
        ("onboardingFeature1Heading", "onboardingFeature1Sub"),
        ("onboardingFeature2Heading", "onboardingFeature2Sub"),
        ("onboardingFeature3Heading", "onboardingFeature3Sub"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            heroIcon
                .padding(.top, 60)
                .padding(.bottom, 36)

            Text("onboardingTitle")
                .font(.dduLargeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.md)

            Text("onboardingScreenTimeDesc")
                .font(.dduBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)
                .padding(.bottom, 36)

            VStack(spacing: 14) {
                ForEach(Array(bulletKeys.enumerated()), id: \.offset) { index, item in
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
                            Text("onboardingButtonScreenTime")
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
                    Text("onboardingHelperText")
                        .font(.dduCaption1)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, 40)
        }
        .background(Color.surfaceGrouped.ignoresSafeArea())
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

            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
        }
        .frame(width: 120, height: 120)
    }

    private func bulletRow(index: Int, heading: LocalizedStringKey, sub: LocalizedStringKey) -> some View {
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
