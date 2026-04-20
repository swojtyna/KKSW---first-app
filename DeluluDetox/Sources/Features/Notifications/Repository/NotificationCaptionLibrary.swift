import Foundation

/// Copy libraries for Phase 6 notifications + broken streak (CONTEXT §D-10, §D-17, §D-20).
/// Rotation is deterministic per-session (NTF-01 uses sessionId-derived hash),
/// per-call (NTF-02 uses scheduleId-derived hash). Claude's Discretion finalizes
/// copy wording during execution; drafts below honor the sarcastic-playful tone (§D-12 Phase 3).
struct NotificationCaptionLibrary: Sendable {

    // CONTEXT §D-17 — miękki sarkazm + celebracja (NTF-01).
    let sessionEndCaptions: [String] = [
        "Przetrwałeś %d min bez scrollowania. Świat się nie zawalił.",
        "Sesja ukończona. Możesz wrócić do chaosu.",
        "Gratuluję, %d min w realnym świecie. Teraz możesz pojeździć palcem."
    ]

    // CONTEXT §D-20 — miękki sarkazm + info (NTF-02).
    let scheduleStartCaptions: [String] = [
        "Schedule właśnie zaczął blokadę. Powodzenia.",
        "Apki wyłączone. Realny świat prosi o uwagę.",
        "Blokada zaczyna się teraz. Telefon idzie spać."
    ]

    // CONTEXT §D-10 — ostry shame (broken streak). Kept separately because
    // tonal register differs: shame vs. celebratory.
    let brokenStreakCaptions: [String] = [
        "Straciłeś %d-dniową serię. Imponujące.",
        "%d dni do kosza. Brawo.",
        "Seria %d dni właśnie wyparowała. Gratulacje."
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
