import SwiftUI

struct SessionSuccessView: View {
    @Bindable var model: SessionSuccessViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

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

                Image(systemName: "sparkles")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 120, height: 120)
            .padding(.bottom, Theme.Spacing.xxl)

            Text("Wytrzymałeś \(model.durationMinutes) minut")
                .font(.dduLargeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.sm)

            Text(model.caption)
                .font(.dduBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxxl)

            Spacer()

            PrimaryButton(title: "Dzięki, wiem", systemIcon: "hand.thumbsup.fill") {
                onDismiss()
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceGrouped.ignoresSafeArea())
    }
}
