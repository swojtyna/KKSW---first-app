import Foundation

/// Validated session duration wrapper.
///
/// Enforces CONTEXT §D-18 range: 5 min lower bound (QSN-02) up to 8 h upper
/// bound (QSN-02). QSN-01 presets (15/30/60/90 min) surface via `preset(_:)`.
struct SessionDuration: Codable, Equatable, Sendable {
    static let minSeconds: Int = 5 * 60
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
