import Foundation

/// Three-case outcome enum for session finalization.
/// Raw string values match CONTEXT §D-08 / §D-14 for unambiguous Phase 6 gamification queries.
enum SessionOutcome: String, Codable, Sendable {
    case completed
    case cancelledByUser = "cancelled_by_user"
    case brokenByRevoke = "broken_by_revoke"
}
