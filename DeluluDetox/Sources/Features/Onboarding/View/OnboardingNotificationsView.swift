import SwiftUI

struct OnboardingNotificationsView: View {
    @Bindable var model: OnboardingNotificationsViewModel

    var body: some View {
        VStack(spacing: 0) {
            heroIcon
                .padding(.top, 60)
                .padding(.bottom, 36)

            Text("notificationsOnboardingTitle")
                .font(.dduLargeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.md)

            Text("notificationsOnboardingDesc")
                .font(.dduBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)
                .padding(.bottom, 36)

            Spacer(minLength: Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.md) {
                Button {
                    Task { await model.allowTapped() }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        if model.isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("notificationsOnboardingButtonAllow")
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

                Button {
                    model.skipTapped()
                } label: {
                    Text("notificationsOnboardingButtonSkip")
                        .font(.dduFootnote)
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(model.isRequesting)

                Text("notificationsOnboardingHelperText")
                    .font(.dduCaption1)
                    .foregroundStyle(Color.textTertiary)
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

            Image(systemName: "bell.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.white)
        }
        .frame(width: 120, height: 120)
    }
}

#Preview {
    let container = DIContainer.shared
    container.reset()
    NotificationsInjection.register(in: container)
    return OnboardingNotificationsView(model: OnboardingNotificationsViewModel())
}
