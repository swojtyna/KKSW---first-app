@preconcurrency import DeviceActivity

/// Shared DeviceActivityName constants used by BOTH the main app and the
/// DeviceActivityMonitor extension (Phase 3 P04). Keeping the constant in one
/// place ensures the main-app `startMonitoring(_:during:)` registration and
/// the extension's `intervalDidEnd(for:)` dispatch agree on the activity name.
///
/// Do NOT change the rawValue without updating both ends.
enum SessionActivityNames {
    static let quickSession = DeviceActivityName("deluludetox.quickSession")
}
