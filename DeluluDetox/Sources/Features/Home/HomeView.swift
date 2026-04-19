import SwiftUI

struct HomeView: View {
    @Bindable var model: HomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityLabel("Phone with apps")

                Spacer().frame(height: Theme.Spacing.lg)

                Text("No Apps Blocked Yet")
                    .font(.dduTitle2)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Theme.Spacing.sm)

                Text("Pick the apps that steal your time. We\u{2019}ll do the rest.")
                    .font(.dduBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)

                Spacer().frame(height: Theme.Spacing.xxxl)

                Button {
                    model.chooseAppsTapped()
                } label: {
                    Text("Choose Apps to Block")
                        .font(.dduHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandViolet)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .padding(.horizontal, Theme.Spacing.xxl)
            }

            Spacer()
        }
        .background(Color.surfaceBg)
        .navigationTitle("DeluluDetox")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        HomeView(model: HomeViewModel())
    }
}
