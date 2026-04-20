import Foundation

/// Lightweight envelope decoded from `active_session.json` by the Shield
/// extensions. Decodes ONLY `plannedEndAt` — pulling in the full
/// `SessionRecord` would transitively import FamilyControls-adjacent types
/// and blow the 6 MB extension RAM ceiling (Phase 3 Plan 04 established
/// pattern; PROJECT.md Hard Constraint §8).
///
/// Date encoding strategy MUST match SessionRepositoryImpl (verified via
/// Plan 01 grep + RESEARCH.md Pitfall 3): both sides use vanilla
/// `JSONEncoder()`/`JSONDecoder()` → default `.deferredToDate`
/// (TimeInterval since 2001-01-01). Do NOT set a custom strategy here.
struct ActiveSessionEnvelope: Decodable {
    let plannedEndAt: Date
}

enum ActiveSessionEnvelopeReader {
    /// Returns `Int?` minutes remaining (rounded UP to ≥1 if any time left),
    /// or `nil` if the file is missing, empty, malformed, or already expired.
    /// Never throws — every error path collapses to `nil` (D-11 fallback gate).
    static func loadRemainingMinutes(now: Date = Date()) -> Int? {
        guard let url = try? SessionPaths.activeSessionURL(),
              let data = try? Data(contentsOf: url),
              !data.isEmpty,
              let envelope = try? JSONDecoder().decode(ActiveSessionEnvelope.self, from: data)
        else { return nil }
        let remaining = envelope.plannedEndAt.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        // Round UP so a session ending in 45 seconds shows "1 min", not "0 min".
        let minutes = Int((remaining + 59) / 60)
        return max(1, minutes)
    }
}
