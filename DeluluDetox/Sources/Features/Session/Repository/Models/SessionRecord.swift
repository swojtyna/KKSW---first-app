import Foundation

/// Single persisted session — CONTEXT §D-14 full schema from day 1.
///
/// `outcome == nil && actualEndAt == nil` ⇒ session is active. The main app
/// is the sole writer per CONTEXT §D-03; DAM extension writes only a
/// `SessionFinalizeMarker` that the main app reconciles on next foreground.
struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    typealias ID = UUID

    let id: UUID
    let blocklistId: UUID
    let startedAt: Date
    let plannedEndAt: Date
    let plannedDurationSeconds: Int
    var actualEndAt: Date?
    var outcome: SessionOutcome?
    let appVersion: String

    var isActive: Bool { outcome == nil && actualEndAt == nil }

    init(
        id: UUID = UUID(),
        blocklistId: UUID,
        startedAt: Date,
        plannedEndAt: Date,
        plannedDurationSeconds: Int,
        actualEndAt: Date? = nil,
        outcome: SessionOutcome? = nil,
        appVersion: String
    ) {
        self.id = id
        self.blocklistId = blocklistId
        self.startedAt = startedAt
        self.plannedEndAt = plannedEndAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.actualEndAt = actualEndAt
        self.outcome = outcome
        self.appVersion = appVersion
    }
}
