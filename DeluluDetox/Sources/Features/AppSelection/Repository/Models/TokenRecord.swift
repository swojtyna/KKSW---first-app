import FamilyControls
import Foundation
import ManagedSettings

/// Single opaque entry persisted in the blocklist.
///
/// Keyed by an app-generated `UUID` (D-05 / SEL-05) so record identity survives
/// Apple token-binary rotation (FB14082790 et al.). The `encodedToken` is the
/// raw JSON-encoded form of the concrete Apple token type (per `kind`) and is
/// reconstituted for rendering by the View layer via the `*Token()` helpers.
struct TokenRecord: Codable, Equatable, Identifiable, Sendable {
    typealias ID = UUID

    let id: UUID
    let kind: TokenKind
    var encodedToken: Data
    var lastSeenAt: Date

    func applicationToken() -> ApplicationToken? {
        guard kind == .application else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: encodedToken)
    }

    func categoryToken() -> ActivityCategoryToken? {
        guard kind == .category else { return nil }
        return try? JSONDecoder().decode(ActivityCategoryToken.self, from: encodedToken)
    }

    func webDomainToken() -> WebDomainToken? {
        guard kind == .webDomain else { return nil }
        return try? JSONDecoder().decode(WebDomainToken.self, from: encodedToken)
    }
}
