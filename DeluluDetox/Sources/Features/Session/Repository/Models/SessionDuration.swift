import Foundation

/// Validated session duration wrapper.
///
/// Lower bound is 15 min — Apple's DeviceActivitySchedule requires at least a
/// 15-minute interval; shorter schedules are silently rejected (or fire
/// intervalDidEnd immediately), which finalizes the session before the
/// countdown is visible. Upper bound is 8 h (QSN-02). Presets 15/30/60/90 min
/// surface via `preset(_:)`.
struct SessionDuration: Codable, Equatable, Sendable {
    static let minSeconds: Int = 15 * 60
    static let maxSeconds: Int = 8 * 60 * 60
    static let presetMinutes: [Int] = [15, 30, 60, 90]

    let seconds: Int

    init?(seconds: Int) {
        guard seconds >= Self.minSeconds, seconds <= Self.maxSeconds else { return nil }
        self.seconds = seconds
    }

    /// Convenience for QSN-01 preset chips.
    static func preset(_ minutes: Int) -> SessionDuration? {
        SessionDuration(seconds: minutes * 60)
    }
}
