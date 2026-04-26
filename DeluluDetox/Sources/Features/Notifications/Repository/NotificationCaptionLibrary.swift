import Foundation

/// Copy libraries for Phase 6 notifications + broken streak (CONTEXT §D-10, §D-17, §D-20).
/// Rotation is deterministic per-session (NTF-01 uses sessionId-derived hash),
/// per-call (NTF-02 uses scheduleId-derived hash). Uses NSLocalizedString so
/// notification content respects the device locale (architectural exception:
/// string lookup in Repository layer because notification body is data, not UI).
struct NotificationCaptionLibrary: Sendable {

    // CONTEXT §D-17 — miękki sarkazm + celebracja (NTF-01).
    let sessionEndCaptions: [String] = [
        NSLocalizedString("notifSessionEnd1", comment: "NTF-01 session completion"),
        NSLocalizedString("notifSessionEnd2", comment: "NTF-01 session completion"),
        NSLocalizedString("notifSessionEnd3", comment: "NTF-01 session completion"),
    ]

    // CONTEXT §D-20 — miękki sarkazm + info (NTF-02).
    let scheduleStartCaptions: [String] = [
        NSLocalizedString("notifScheduleStart1", comment: "NTF-02 schedule start"),
        NSLocalizedString("notifScheduleStart2", comment: "NTF-02 schedule start"),
        NSLocalizedString("notifScheduleStart3", comment: "NTF-02 schedule start"),
    ]

    // CONTEXT §D-10 — ostry shame (broken streak). Kept separately because
    // tonal register differs: shame vs. celebratory.
    let brokenStreakCaptions: [String] = [
        NSLocalizedString("notifBrokenStreak1", comment: "broken streak shame"),
        NSLocalizedString("notifBrokenStreak2", comment: "broken streak shame"),
        NSLocalizedString("notifBrokenStreak3", comment: "broken streak shame"),
    ]

    /// NTF-01 copy. `hash` is typically `abs(sessionId.uuidString.hashValue)`;
    /// `durationMinutes` interpolates into `%d` when present in the template.
    func sessionEndCopy(for hash: Int, durationMinutes: Int) -> String {
        let idx = abs(hash) % sessionEndCaptions.count
        let template = sessionEndCaptions[idx]
        return template.contains("%d") ? String(format: template, durationMinutes) : template
    }

    /// NTF-02 copy. `hash` is typically `abs(scheduleId.uuidString.hashValue) &+ weekday`.
    func scheduleStartCopy(for hash: Int) -> String {
        let idx = abs(hash) % scheduleStartCaptions.count
        return scheduleStartCaptions[idx]
    }

    /// Broken-streak home card copy (not a notification). `%d` → `longest`.
    func brokenStreakCopy(longestStreak: Int, hash: Int) -> String {
        let idx = abs(hash) % brokenStreakCaptions.count
        let template = brokenStreakCaptions[idx]
        return template.contains("%d") ? String(format: template, longestStreak) : template
    }
}
