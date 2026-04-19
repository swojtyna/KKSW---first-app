import SwiftUI
import SwiftUINavigation

struct CountdownView: View {
    @Bindable var model: CountdownViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ring
            caption
            Spacer()
            earlyEndButton
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Sesja aktywna")
        .navigationBarBackButtonHidden(true)     // can't easily back out — consistent with QSN-05
        .onDisappear { model.onDisappear() }
        .confirmationDialog(
            "Zakończyć wcześniej?",
            isPresented: Binding(
                get: {
                    if case .confirmEarlyEnd = model.destination { return true }
                    return false
                },
                set: { if !$0 { model.dismissConfirm() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Tak, kończę wcześniej", role: .destructive) {
                Task { await model.confirmEarlyEnd() }
            }
            Button("Nie, wytrzymam", role: .cancel) {
                model.dismissConfirm()
            }
        } message: {
            Text("Timer ma jeszcze \(formatRemaining(model.remainingSeconds)). Jesteś pewien?")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: 14)
            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: model.progress)

            VStack(spacing: 4) {
                Text(formatRemaining(model.remainingSeconds))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                Text("pozostało")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(width: 240, height: 240)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var caption: some View {
        Text("Pij wodę, oddychaj. Wyłączone aplikacje same się nie odblokują.")
            .font(.body)
            .foregroundStyle(Theme.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var earlyEndButton: some View {
        Button(role: .destructive) {
            model.earlyEndTapped()
        } label: {
            Text("Zakończ wcześniej")
                .font(.body)
                .bold()
                .foregroundStyle(Theme.destructive)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.bordered)
        .tint(Theme.destructive)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Formatting

    private func formatRemaining(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if model.session.plannedDurationSeconds >= 3600 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
