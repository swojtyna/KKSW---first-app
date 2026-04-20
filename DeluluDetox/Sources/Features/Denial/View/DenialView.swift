import SwiftUI

struct DenialView: View {
    @Bindable var model: DenialViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            heroIcon
                .padding(.bottom, Theme.Spacing.xxl)

            Text("Bez Screen Time nic z tego nie będzie.")
                .font(.dduLargeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.md)

            Text("To jak zatrudnić bramkarza i nie wpuścić go do klubu. Wróć do Ustawień i włącz dostęp.")
                .font(.dduBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Button {
                    Task { await model.retryTapped() }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        if model.isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Spróbuj jeszcze raz")
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
                    Text("Ustawienia → Screen Time → Zezwól.")
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
                        colors: [.brandAmber, .brandAmberInk],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.brandAmber.opacity(0.4), radius: 40, x: 0, y: 20)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 120, height: 120)
    }
}

#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    return DenialView(model: DenialViewModel())
}
