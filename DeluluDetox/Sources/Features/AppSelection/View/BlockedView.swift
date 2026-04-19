import FamilyControls
import ManagedSettings
import SwiftUI

/// SwiftUI list of persisted blocks grouped by kind (apps / categories / web).
/// Rendered as the non-empty branch of `HomeView` (wiring lands in Plan 06).
///
/// Section order is fixed: Aplikacje → Kategorie → Strony www. Each section is
/// conditionally shown so empty groups don't render as blank headers. Each row
/// uses Apple's `Label(token)` (only supported renderer for opaque tokens)
/// with a full-swipe destructive trash action — no confirmation dialog per
/// 02-UI-SPEC.md §Destructive actions.
///
/// The bottom "Zmień wybór" CTA sits in a `safeAreaInset(.bottom)` so the list
/// scrolls underneath it (matches HomeView's primary-button style).
/// `BlockedView` does NOT host its own `NavigationStack` — HomeView provides
/// the outer container via AppRootView; the `#Preview` wraps NavigationStack
/// only so the large title renders in Xcode Canvas.
struct BlockedView: View {
    @Bindable var model: BlockedViewModel

    var body: some View {
        List {
            if !model.appRecords.isEmpty {
                Section("Aplikacje") {
                    ForEach(model.appRecords) { record in
                        if let token = record.applicationToken() {
                            Label(token)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await model.deleteTapped(recordID: record.id) }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }

            if !model.categoryRecords.isEmpty {
                Section("Kategorie") {
                    ForEach(model.categoryRecords) { record in
                        if let token = record.categoryToken() {
                            Label(token)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await model.deleteTapped(recordID: record.id) }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }

            if !model.webRecords.isEmpty {
                Section("Strony www") {
                    ForEach(model.webRecords) { record in
                        if let token = record.webDomainToken() {
                            Label(token)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await model.deleteTapped(recordID: record.id) }
                                    } label: {
                                        Label("Usuń", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Zablokowane")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                model.changeSelectionTapped()
            } label: {
                Text("Zmień wybór")
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
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    let container = DIContainer.shared
    container.reset()
    OnboardingInjection.register(in: container)
    AppSelectionInjection.register(in: container)
    return NavigationStack {
        BlockedView(model: BlockedViewModel())
    }
}
