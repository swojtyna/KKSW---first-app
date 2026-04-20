import SwiftUI
import SwiftUINavigation

struct CountdownView: View {
    @Bindable var model: CountdownViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Theme.Spacing.xl)

            ZStack {
                bloom
                progressRing
            }
            .frame(width: 320, height: 320)

            Spacer().frame(height: Theme.Spacing.xxxl)

            Text("„Scrollowanie może poczekać. Ty nie.”")
                .font(.system(size: 20, weight: .semibold).italic())
                .foregroundStyle(Color.brandVioletInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)

            Spacer()

            earlyEndButton
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceGrouped.ignoresSafeArea())
        .navigationTitle("Sesja aktywna")
        .navigationBarBackButtonHidden(true)
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

    private var bloom: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.brandVioletTint, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 180
                )
            )
            .blur(radius: 10)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 14)

            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(
                    LinearGradient(
                        colors: [.brandVioletTint, .brandViolet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.brandViolet.opacity(0.5), radius: 12)
                .animation(.linear(duration: 1.0), value: model.progress)

            VStack(spacing: Theme.Spacing.xs) {
                Text(formatRemaining(model.remainingSeconds))
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                Text("z \(formatTotal)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(Theme.Spacing.xl)
    }

    private var earlyEndButton: some View {
        Button {
            model.earlyEndTapped()
        } label: {
            Text("Zakończ wcześniej")
                .font(.dduHeadline)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
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

    private var formatTotal: String {
        let seconds = model.session.plannedDurationSeconds
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if seconds >= 3600 {
            return String(format: "%d:%02d:00", h, m)
        }
        return String(format: "%02d:00", m)
    }
}
