import Foundation
import UserNotifications
import os

/// D-13 lazy permission prompt. Called from
/// `FinalizeSessionFromMarkerUseCaseImpl.callAsFunction` IMMEDIATELY after
/// `endSession(outcome: .completed, ...)` succeeds and BEFORE the function
/// returns — this is the "first `.completed`" trigger point per CONTEXT §D-13.
/// No-op when the status is anything other than `.notDetermined` — iOS allows
/// one dialog per install, so subsequent completions are safe invocations.
protocol SchedulePermissionPromptUseCase: Sendable {
    func callAsFunction() async
}

final class SchedulePermissionPromptUseCaseImpl: SchedulePermissionPromptUseCase, @unchecked Sendable {
    private let repository: LocalNotificationRepository

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "SchedulePermissionPromptUC"
    )

    init(repository: LocalNotificationRepository) {
        self.repository = repository
    }

    func callAsFunction() async {
        let status = await repository.authorizationStatus()
        guard status == .notDetermined else {
            Self.log.info("permission prompt skipped — status=\(String(describing: status), privacy: .public)")
            return
        }
        // RESEARCH A7: include .sound so default sound is honored for NTF-01/02.
        // Do NOT request the badge option — no badge UX in MVP.
        do {
            let granted = try await repository.requestAuthorization(options: [.alert, .sound])
            Self.log.info("permission prompt result granted=\(granted, privacy: .public)")
        } catch {
            Self.log.error("permission prompt failed: \(String(describing: error), privacy: .public)")
        }
    }
}
