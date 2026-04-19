import Foundation

/// Full Phase 6-ready session record schema.
/// Written by Plan 03-01 (SessionRepository). Used by Plan 03-02 (SessionEnforcer).
///
/// Schema per CONTEXT §D-14:
/// - `plannedEndAt` is stored redundantly (not recomputed from startedAt + duration)
///   so the DAM extension can read it without arithmetic.
/// - `outcome` nil means session is still active.
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
