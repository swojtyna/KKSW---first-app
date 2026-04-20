import Foundation
import UserNotifications
import os

/// Thin facade over `UNUserNotificationCenter` for the main app. Phase 4
/// `ShieldNotificationRepository` (shared with extension target) stays as-is;
/// this is the main-app-only counterpart used by Phase 6 NTF-01/NTF-02 UCs.
///
/// The `authorizationStatus()` accessor exists in lieu of a full
/// `UNNotificationSettings` return value because `UNNotificationSettings` has
/// no public initializer — exposing the narrow enum lets `MockLocalNotificationRepository`
/// stub it for tests without constructing system types.
protocol LocalNotificationRepository: Sendable {
    /// Auth status. Phase 6 UCs gate on `.authorized` (CONTEXT §D-15).
    /// Live impl reads from `UNUserNotificationCenter.current().notificationSettings()`.
    func authorizationStatus() async -> UNAuthorizationStatus

    /// Present the system prompt exactly once (iOS enforces). Returns
    /// `true` iff user granted. Only the D-13 lazy prompt UC calls this.
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Best-effort add. Throwing propagates to the caller but callers
    /// treat notification failures as non-fatal (convenience layer).
    func add(_ request: UNNotificationRequest) async throws

    /// Live pending requests — used by reconcile flows.
    func pendingNotificationRequests() async -> [UNNotificationRequest]

    /// Remove by exact identifier set — synchronous per UN API.
    func removePendingNotificationRequests(withIdentifiers ids: [String])

    /// Convenience: remove every pending request whose identifier starts
    /// with `prefix`. Implemented atop `pendingNotificationRequests()` +
    /// filter. Used by NTF-02 reconcile (remove all `schedule.start.{id}.*`
    /// before re-adding).
    func removePendingNotificationRequests(withIdentifierPrefix prefix: String) async
}

/// Live UN-backed implementation. Stateless. Safe to scope `.application`.
struct LiveLocalNotificationRepository: LocalNotificationRepository {
    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func removePendingNotificationRequests(withIdentifierPrefix prefix: String) async {
        let pending = await pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
