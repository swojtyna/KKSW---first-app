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
                    .foregroundStyle(Theme.tertiaryText)
                    .accessibilityLabel("Phone with apps")

                Spacer().frame(height: 16)

                Text("No Apps Blocked Yet")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("Pick the apps that steal your time. We\u{2019}ll do the rest.")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 32)

                Button {
                    model.chooseAppsTapped()
                } label: {
                    Text("Choose Apps to Block")
                        .font(.body)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .background(Theme.background)
        .navigationTitle("DeluluDetox")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        HomeView(model: HomeViewModel())
    }
}
