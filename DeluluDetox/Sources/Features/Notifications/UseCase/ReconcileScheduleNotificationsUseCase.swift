import Foundation
import UserNotifications
import os

/// NTF-02 reconcile (CONTEXT §D-18).
/// "Full replace" semantics: every call removes ALL pending `schedule.start.{id}.*`
/// for this schedule and re-adds per-weekday requests matching the current
/// schedule state. Idempotent — safe to call from SyncScheduleWithSystemUseCase
/// (post-startMonitoring AND on disabled-early-return) AND on foreground
/// reliability check.
///
/// Cross-midnight (CONTEXT §D-18 + Phase 5 §D-03): for schedules that wrap past
/// midnight, ONLY the evening (user-visible start) gets a notification. The
/// morning segment is a technical artifact of the DAS split — notifying the
/// user at 00:00 is confusing and already implied by the evening banner.
protocol ReconcileScheduleNotificationsUseCase: Sendable {
    func callAsFunction(schedule: Schedule) async
}

final class ReconcileScheduleNotificationsUseCaseImpl: ReconcileScheduleNotificationsUseCase, @unchecked Sendable {
    private let repository: LocalNotificationRepository
    private let captions: NotificationCaptionLibrary

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ReconcileScheduleNotificationsUC"
    )

    init(repository: LocalNotificationRepository, captions: NotificationCaptionLibrary) {
        self.repository = repository
        self.captions = captions
    }

    func callAsFunction(schedule: Schedule) async {
        let prefix = "schedule.start.\(schedule.id.uuidString)."

        // Step 1 — full replace: always remove any pending for this id.
        await repository.removePendingNotificationRequests(withIdentifierPrefix: prefix)

        // Step 2 — if disabled, we're done.
        guard schedule.enabled else {
            Self.log.info("NTF-02 reconcile: schedule disabled id=\(schedule.id.uuidString, privacy: .public)")
            return
        }

        // Step 3 — auth gate (still clears stale above — defensive).
        let status = await repository.authorizationStatus()
        guard status == .authorized else {
            Self.log.info("NTF-02 reconcile: not authorized status=\(String(describing: status), privacy: .public)")
            return
        }

        // Step 4 — ignore empty day set (UI allows save with no days; no point
        // creating zero requests; defensive).
        guard !schedule.daysOfWeek.isEmpty else {
            Self.log.info("NTF-02 reconcile: empty daysOfWeek id=\(schedule.id.uuidString, privacy: .public)")
            return
        }

        // Step 5 — per weekday, create one repeating trigger matching the
        // user-visible start time (startHour/startMinute). Cross-midnight:
        // morning segment (00:00 -> endHour) is NOT notified per CONTEXT §D-18.
        // We notify at startHour/startMinute regardless of crossesMidnight.
        let hashBase = Int(schedule.id.uuidString.unicodeScalars.first?.value ?? 0)
        for weekday in schedule.daysOfWeek {
            let identifier = "schedule.start.\(schedule.id.uuidString).\(weekday)"
            let content = UNMutableNotificationContent()
            content.title = "DeluluDetox"
            content.body = captions.scheduleStartCopy(for: hashBase &+ weekday)
            content.sound = .default
            content.userInfo = [
                "kind": "schedule-start",
                "scheduleId": schedule.id.uuidString
            ]

            // RESEARCH §Pitfall 7 — ALWAYS set explicit calendar + timezone.
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = TimeZone.current
            components.hour = schedule.startHour
            components.minute = schedule.startMinute
            components.weekday = weekday

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await repository.add(request)
            } catch {
                Self.log.error(
                    "NTF-02 add failed id=\(identifier, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }

        Self.log.info(
            "NTF-02 reconcile added=\(schedule.daysOfWeek.count, privacy: .public) id=\(schedule.id.uuidString, privacy: .public)"
        )
    }
}
