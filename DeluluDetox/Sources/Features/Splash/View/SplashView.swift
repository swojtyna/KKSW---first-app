import SwiftUI

/// Standalone brand splash — no view model, no persistence. AppRootView
/// may show this briefly while the authorization status publisher emits
/// its first value. Ported from the design handoff SplashScreenView.
struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RadialGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.165, green: 0.094, blue: 0.329), .black]
                    : [Color(red: 0.929, green: 0.894, blue: 0.992), .surfaceGrouped],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.brandVioletTint, .brandViolet, .brandVioletInk],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: [.white.opacity(0.25), .clear],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .shadow(color: Color.brandViolet.opacity(0.5), radius: 30, x: 0, y: 24)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 140, height: 140)

                VStack(spacing: Theme.Spacing.sm) {
                    Text("DeluluDetox")
                        .font(.system(size: 40, weight: .heavy))
                        .kerning(-1)
                        .foregroundStyle(Color.textPrimary)

                    Text("Mniej scrolla. Mniej wymówek.")
                        .font(.dduBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Text("v1.0 · made with ✊ in PL")
                    .font(.dduCaption1)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.bottom, 60)
            }
        }
    }
}

#Preview("Light") {
    SplashView().preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashView().preferredColorScheme(.dark)
}
