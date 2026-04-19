import SwiftUI

struct DenialView: View {
    @Bindable var model: DenialViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("Raised hand")

                Spacer().frame(height: 16)

                Text("Nice Try")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("DeluluDetox literally cannot work without Screen Time access. That\u{2019}s like hiring a bouncer and not letting them in the club.")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 32)

                Button {
                    Task { await model.retryTapped() }
                } label: {
                    Group {
                        if model.isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Let\u{2019}s Try Again")
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

                if let errorMessage = model.error {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }
            }

            Spacer()
        }
        .background(Theme.background)
    }
}

#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)  // Denial konsumuje Request UC z Onboarding registration (D-17)
    return DenialView(model: DenialViewModel())
}
