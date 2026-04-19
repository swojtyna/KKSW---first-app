import Foundation
import Observation

@MainActor
@Observable
final class SessionSuccessViewModel: Identifiable, @unchecked Sendable {
    /// `nonisolated` so `Identifiable` conformance (used by `.sheet(item:)`) can
    /// be satisfied without a MainActor hop. Same value as `sessionId`.
    nonisolated let id: UUID
    let sessionId: UUID
    let durationMinutes: Int
    let caption: String

    /// Stable caption pool; pick deterministically by session id hash so the
    /// user doesn't get a "flicker" if the view redraws.
    private static let captions: [String] = [
        "Odłożyłeś telefon jak dorosły człowiek.",
        "Świat się nie zawalił.",
        "Dobra robota. Nie, serio.",
        "Czas leci tak samo jak scroll, tylko mądrzej."
    ]

    init(session: SessionRecord) {
        self.id = session.id
        self.sessionId = session.id
        self.durationMinutes = session.plannedDurationSeconds / 60
        let idx = abs(session.id.uuidString.hashValue) % Self.captions.count
        self.caption = Self.captions[idx]
    }
}
