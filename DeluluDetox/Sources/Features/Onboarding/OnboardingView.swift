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
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Phone with lock")

                Spacer().frame(height: 16)

                Text("Your Phone Is Winning")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("DeluluDetox needs Screen Time access to block distracting apps. No data leaves your device \u{2014} ever.")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 32)

                Button {
                    Task { await model.grantAccessTapped() }
                } label: {
                    Group {
                        if model.isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Grant Access")
                                .font(.body)
                                .bold()
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(model.isRequesting)
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .background(Theme.background)
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
