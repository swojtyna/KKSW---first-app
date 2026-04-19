import SwiftUI

struct SessionSuccessView: View {
    @Bindable var model: SessionSuccessViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
            Text("Wytrzymałeś \(model.durationMinutes) minut")
                .font(.title)
                .bold()
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
            Text(model.caption)
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Text("Dzięki, wiem")
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
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .onTapGesture { onDismiss() }
    }
}
