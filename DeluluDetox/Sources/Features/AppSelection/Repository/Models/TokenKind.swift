import Foundation

/// Discriminator for `TokenRecord`. Each kind maps to one of the three token
/// families surfaced by `FamilyActivitySelection` (`applicationTokens` /
/// `categoryTokens` / `webDomainTokens`).
enum TokenKind: String, Codable, Sendable {
    case application
    case category
    case webDomain
}
