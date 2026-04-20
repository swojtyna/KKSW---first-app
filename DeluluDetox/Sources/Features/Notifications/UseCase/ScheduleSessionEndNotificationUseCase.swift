import Foundation
import UserNotifications
import os

/// NTF-01 schedule hook (CONTEXT §D-15).
/// Called from `StartSessionUseCaseImpl.callAsFunction` AFTER step 3 succeeds
/// (monitoring.startActivityMonitoring). Best-effort — any UN error is logged
/// and swallowed (notification is convenience; session is critical).
protocol ScheduleSessionEndNotificationUseCase: Sendable {
    func callAsFunction(sessionId: UUID, plannedEndAt: Date, durationMinutes: Int) async
}

final class ScheduleSessionEndNotificationUseCaseImpl: ScheduleSessionEndNotificationUseCase, @unchecked Sendable {
    private let repository: LocalNotificationRepository
    private let captions: NotificationCaptionLibrary

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ScheduleSessionEndNotificationUC"
    )

    init(repository: LocalNotificationRepository, captions: NotificationCaptionLibrary) {
        self.repository = repository
        self.captions = captions
    }

    func callAsFunction(sessionId: UUID, plannedEndAt: Date, durationMinutes: Int) async {
        let status = await repository.authorizationStatus()
        guard status == .authorized else {
            Self.log.info("NTF-01 skipped — status=\(String(describing: status), privacy: .public)")
            return
        }

        // Deterministic hash across process launches (RESEARCH OQ#2):
        // `Int.hashValue` is randomized per-process in Swift 4.2+. Use the
        // first ascii byte of the uuid string for test-stable rotation.
        let hashSeed = Int(sessionId.uuidString.unicodeScalars.first?.value ?? 0)

        let identifier = "session.end.\(sessionId.uuidString)"
        let content = UNMutableNotificationContent()
        content.title = "DeluluDetox"
        content.body = captions.sessionEndCopy(for: hashSeed, durationMinutes: durationMinutes)
        content.sound = .default
        content.userInfo = [
            "kind": "session-end",
            "sessionId": sessionId.uuidString
        ]

        // Mirror RESEARCH §Pattern 2: build a DateComponents matching the wall-clock
        // fields of plannedEndAt, so UNCalendarNotificationTrigger fires once at that
        // exact second.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let extracted = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: plannedEndAt
        )
        var keeper = DateComponents()
        keeper.calendar = cal
        keeper.timeZone = TimeZone.current
        keeper.year = extracted.year
        keeper.month = extracted.month
        keeper.day = extracted.day
        keeper.hour = extracted.hour
        keeper.minute = extracted.minute
        keeper.second = extracted.second
        let trigger = UNCalendarNotificationTrigger(dateMatching: keeper, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        do {
            try await repository.add(request)
            Self.log.info("NTF-01 scheduled id=\(identifier, privacy: .public)")
        } catch {
            Self.log.error("NTF-01 add failed: \(String(describing: error), privacy: .public)")
        }
    }
}
