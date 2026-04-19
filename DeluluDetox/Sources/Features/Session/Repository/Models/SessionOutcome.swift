import Foundation

/// Outcome of a completed or aborted session.
///
/// Raw values match CONTEXT §D-08 / §D-14 snake_case strings so Phase 6
/// gamification can query them unambiguously across platform boundaries.
enum SessionOutcome: String, Codable, Sendable {
    case completed
    case cancelledByUser = "cancelled_by_user"
    case brokenByRevoke = "broken_by_revoke"
}
