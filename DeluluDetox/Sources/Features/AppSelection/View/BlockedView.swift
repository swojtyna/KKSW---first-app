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

    @State private var showClearConfirm: Bool = false

    var body: some View {
        List {
            if !model.appRecords.isEmpty {
                Section("blockedSectionApps") {
                    ForEach(model.appRecords) { record in
                        if let token = record.applicationToken() {
                            Label(token)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await model.deleteTapped(recordID: record.id) }
                                    } label: {
                                        Label("blockedButtonDelete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }

            if !model.categoryRecords.isEmpty {
                Section("blockedSectionCategories") {
                    ForEach(model.categoryRecords) { record in
                        if let token = record.categoryToken() {
                            Label(token)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await model.deleteTapped(recordID: record.id) }
                                    } label: {
                                        Label("blockedButtonDelete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }

            if !model.webRecords.isEmpty {
                Section("blockedSectionWebsites") {
                    ForEach(model.webRecords) { record in
                        if let token = record.webDomainToken() {
                            Label(token)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await model.deleteTapped(recordID: record.id) }
                                    } label: {
                                        Label("blockedButtonDelete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "blockedNavigationTitle"))
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: String(localized: "blockedButtonEdit"), systemIcon: "plus") {
                    model.changeSelectionTapped()
                }
                SecondaryButton(title: String(localized: "blockedButtonClear"), systemIcon: "trash.fill") {
                    showClearConfirm = true
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .confirmationDialog(
            "blockedClearConfirmTitle",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("blockedClearConfirmButton", role: .destructive) {
                model.clearListTapped()
            }
            Button("blockedClearCancelButton", role: .cancel) { }
        } message: {
            Text("blockedClearConfirmMessage")
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
