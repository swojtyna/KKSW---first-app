import Foundation

/// Append-only history row (CONTEXT §D-17). Main app appends to
/// `schedule_events.json`; Phase 6 consumes for NTF-02 notifications.
struct ScheduleEvent: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case started, ended }
    let scheduleId: UUID
    let kind: Kind
    let timestamp: Date
}
