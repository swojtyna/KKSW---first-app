import Foundation

/// DAM → main app handoff payload (CONTEXT §D-03).
///
/// DAM extension writes this file on `intervalDidEnd` and fires a Darwin
/// notification. Main app reconciles on next foreground, then deletes the
/// file via `SessionRepository.consumeFinalizeMarker()`.
struct SessionFinalizeMarker: Codable, Equatable, Sendable {
    let sessionId: UUID
    let finalizedAt: Date
    let source: Source

    enum Source: String, Codable, Sendable {
        case damIntervalDidEnd = "dam_interval_did_end"
        case damError = "dam_error"
    }
}
