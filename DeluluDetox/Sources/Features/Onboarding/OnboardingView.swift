import SwiftUI

struct OnboardingView: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Image(systemName: "lock.iphone")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.brandViolet)
                    .accessibilityLabel("Phone with lock")

                Spacer().frame(height: Theme.Spacing.lg)

                Text("Your Phone Is Winning")
                    .font(.dduLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Theme.Spacing.sm)

                Text("DeluluDetox needs Screen Time access to block distracting apps. No data leaves your device \u{2014} ever.")
                    .font(.dduBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)

                Spacer().frame(height: Theme.Spacing.xxxl)

                Button {
                    Task { await model.grantAccessTapped() }
                } label: {
                    Group {
                        if model.isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Grant Access")
                                .font(.dduHeadline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandViolet)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .disabled(model.isRequesting)
                .padding(.horizontal, Theme.Spacing.xxl)

                if let errorMessage = model.error {
                    Text(errorMessage)
                        .font(.dduFootnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xxl)
                        .padding(.top, Theme.Spacing.md)
                }
            }

            Spacer()
        }
        .background(Color.surfaceBg)
    }
}

#Preview {
    OnboardingView(
        model: OnboardingViewModel(
            requestAuth: RequestScreenTimeAuthUseCaseImpl(
                repository: ScreenTimeAuthRepositoryImpl()
            )
        )
    )
}
