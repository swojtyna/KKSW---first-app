import Foundation

/// DAM → main-app handoff payload written from `intervalDidStart` /
/// `intervalDidEnd` (CONTEXT §D-17). One marker file per event, named
/// `schedule_event_marker_{unix_millis}.json` — multiple markers coexist
/// (RESEARCH Open Question #4: cross-midnight would overwrite a single
/// marker; timestamp suffix preserves both evening-start and morning-end).
struct ScheduleEventMarker: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case started, ended }
    let scheduleId: UUID
    let kind: Kind
    let timestamp: Date
}
