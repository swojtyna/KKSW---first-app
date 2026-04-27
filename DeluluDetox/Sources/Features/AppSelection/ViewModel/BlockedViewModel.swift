import Combine
import Foundation
import Observation
import os

/// ViewModel for the "Zablokowane" review surface (SEL-04).
///
/// Subscribes to `ObserveBlocklistUseCase` on init and funnels each `Blocklist`
/// emission into three kind-partitioned arrays consumed by `BlockedView`.
/// Exposes `deleteTapped(recordID:)` for swipe-to-delete and a
/// `onChangeSelection` callback hook that `HomeView` (Plan 06) wires up to
/// its picker Destination — the VM itself never knows about SwiftUI or the
/// picker, preserving the View→VM→UseCase dependency rule.
///
/// ViewModel is SwiftUI-free — clean Architecture Presentation-boundary discipline.
@MainActor
@Observable
final class BlockedViewModel: @unchecked Sendable {
    private(set) var appRecords: [TokenRecord] = []
    private(set) var categoryRecords: [TokenRecord] = []
    private(set) var webRecords: [TokenRecord] = []
    private(set) var errorMessage: String?

    /// Wired by `HomeView` in Plan 06 — taps on the "Zmień wybór" CTA forward
    /// up to `HomeViewModel` which owns the picker Destination. The closure
    /// pattern is sanctioned per 02-RESEARCH.md §"BlockedViewModel" note: VM
    /// lifetime is bounded by `HomeView`'s `@State private var blockedModel`,
    /// and the closure captures `[weak model]` in the parent to avoid
    /// retain cycles.
    var onChangeSelection: (() -> Void)?

    /// Wired by `HomeView` — taps on the "Wyczyść listę" CTA forward up to
    /// `HomeViewModel.clearBlocklistTapped()`, which commits an empty
    /// FamilyActivitySelection via UpdateBlocklistUseCase.
    var onClearList: (() -> Void)?

    @ObservationIgnored
    @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase

    @ObservationIgnored
    @LazyInjected private var removeRecord: RemoveTokenRecordUseCase

    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored
    private let logger = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "BlockedVM"
    )

    init() {
        observeBlocklist.execute()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] blocklist in
                guard let self else { return }
                self.appRecords = blocklist.records.filter { $0.kind == .application }
                self.categoryRecords = blocklist.records.filter { $0.kind == .category }
                self.webRecords = blocklist.records.filter { $0.kind == .webDomain }
            }
            .store(in: &cancellables)
    }

    func deleteTapped(recordID: TokenRecord.ID) async {
        errorMessage = nil
        do {
            try await removeRecord.execute(recordID)
            logger.info("record removed id=\(recordID.uuidString, privacy: .public)")
        } catch {
            errorMessage = "Nie udało się usunąć."
            logger.error("remove failed: \(String(describing: error), privacy: .public)")
        }
    }

    func changeSelectionTapped() {
        onChangeSelection?()
    }

    func clearListTapped() {
        onClearList?()
    }
}
