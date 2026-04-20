import Foundation

/// Canonical store names so Phase 3 / Phase 5 literals never drift.
/// Clearing one store MUST NOT affect the other (D-05 schedule × session).
///
/// - `session` — quick session (Phase 3 D-07).
/// - `schedule` — recurring schedule (Phase 5 D-05).
enum ManagedSettingsStoreNames {
    static let session = "deluludetox.session"
    static let schedule = "deluludetox.schedule"
}
