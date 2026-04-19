@preconcurrency import FamilyControls
import Foundation
import ManagedSettings

/// Persisted aggregate for Phase 02 app selection.
///
/// D-01: data model supports N named lists; MVP surfaces one implicit list.
/// D-02: persisted as JSON in the App Group container by `BlocklistRepository`.
/// D-05: records keyed by app-generated UUID with token as best-effort pointer.
///
/// `lastSelection` caches the whole `FamilyActivitySelection` so `FamilyActivityPicker`
/// can be re-seeded accurately (forum 721973 — reconstructing from individual tokens
/// loses `includeEntireCategory`). `needsRepair` reserves schema space for Phase 3+
/// shield-level token drift detection; Phase 02 never flips it true.
struct Blocklist: Codable, Equatable, Sendable {
    let id: UUID
    var name: String?
    var records: [TokenRecord]
    var lastSelection: FamilyActivitySelection
    var updatedAt: Date
    var needsRepair: Bool

    static func empty(id: UUID = UUID()) -> Blocklist {
        Blocklist(
            id: id,
            name: nil,
            records: [],
            lastSelection: FamilyActivitySelection(),
            updatedAt: Date(),
            needsRepair: false
        )
    }

    /// Produce a new Blocklist reconciled with a fresh `FamilyActivitySelection` from the picker.
    /// Preserves existing record UUIDs where the encoded token bytes match (idempotent re-adds),
    /// mints new UUIDs for new tokens, and drops records whose token is no longer in the selection.
    func merging(selection next: FamilyActivitySelection) -> Blocklist {
        var preserved: [TokenRecord] = []

        for token in next.applicationTokens {
            let encoded = (try? JSONEncoder().encode(token)) ?? Data()
            if let existing = records.first(where: { $0.kind == .application && $0.encodedToken == encoded }) {
                var refreshed = existing
                refreshed.lastSeenAt = Date()
                preserved.append(refreshed)
            } else {
                preserved.append(TokenRecord(
                    id: UUID(), kind: .application,
                    encodedToken: encoded, lastSeenAt: Date()
                ))
            }
        }

        for token in next.categoryTokens {
            let encoded = (try? JSONEncoder().encode(token)) ?? Data()
            if let existing = records.first(where: { $0.kind == .category && $0.encodedToken == encoded }) {
                var refreshed = existing
                refreshed.lastSeenAt = Date()
                preserved.append(refreshed)
            } else {
                preserved.append(TokenRecord(
                    id: UUID(), kind: .category,
                    encodedToken: encoded, lastSeenAt: Date()
                ))
            }
        }

        for token in next.webDomainTokens {
            let encoded = (try? JSONEncoder().encode(token)) ?? Data()
            if let existing = records.first(where: { $0.kind == .webDomain && $0.encodedToken == encoded }) {
                var refreshed = existing
                refreshed.lastSeenAt = Date()
                preserved.append(refreshed)
            } else {
                preserved.append(TokenRecord(
                    id: UUID(), kind: .webDomain,
                    encodedToken: encoded, lastSeenAt: Date()
                ))
            }
        }

        return Blocklist(
            id: id,
            name: name,
            records: preserved,
            lastSelection: next,
            updatedAt: Date(),
            needsRepair: false
        )
    }

    /// Phase 02 MVP — bumps updatedAt and returns self. Phase 3+ will implement
    /// real token-rotation verification against `ManagedSettingsStore`.
    func reconcileTokenPointers() -> Blocklist {
        var copy = self
        copy.updatedAt = Date()
        return copy
    }
}
