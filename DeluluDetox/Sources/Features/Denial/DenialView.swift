import SwiftUI

struct DenialView: View {
    @Bindable var model: DenialViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.brandViolet)
                    .accessibilityLabel("Raised hand")

                Spacer().frame(height: Theme.Spacing.lg)

                Text("Nice Try")
                    .font(.dduLargeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Theme.Spacing.sm)

                Text("DeluluDetox literally cannot work without Screen Time access. That\u{2019}s like hiring a bouncer and not letting them in the club.")
                    .font(.dduBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)

                Spacer().frame(height: Theme.Spacing.xxxl)

                Button {
                    Task { await model.retryTapped() }
                } label: {
                    Group {
                        if model.isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Let\u{2019}s Try Again")
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
    DenialView(
        model: DenialViewModel(
            requestAuth: RequestScreenTimeAuthUseCaseImpl(
                repository: ScreenTimeAuthRepositoryImpl()
            )
        )
    )
}
