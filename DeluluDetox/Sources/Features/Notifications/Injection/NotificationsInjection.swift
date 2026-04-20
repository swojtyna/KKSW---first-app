// Features/Notifications/Injection/NotificationsInjection.swift
//
// Distributed DI registration for the Notifications feature. Feature-owner of
// `LocalNotificationRepository` + `NotificationCaptionLibrary` and (as of
// Plans 03 + 04) the NTF-01 / NTF-02 / permission-prompt UseCases.
// Called from `DeluluDetoxApp.init()` as the FIRST injection — other features
// (Session, Scheduling, Stats) resolve `LocalNotificationRepository` from
// this container.

enum NotificationsInjection {
    static func register(in container: DIContainer) {
        container.register(LocalNotificationRepository.self, scope: .application) { _ in
            LiveLocalNotificationRepository()
        }
        container.register(NotificationCaptionLibrary.self, scope: .application) { _ in
            NotificationCaptionLibrary()
        }
        // NTF-01 (Plan 06-03)
        container.register(ScheduleSessionEndNotificationUseCase.self, scope: .unique) { c in
            ScheduleSessionEndNotificationUseCaseImpl(
                repository: c.resolve(),
                captions: c.resolve()
            )
        }
        container.register(CancelSessionEndNotificationUseCase.self, scope: .unique) { c in
            CancelSessionEndNotificationUseCaseImpl(repository: c.resolve())
        }
        // D-13 lazy prompt (Plan 06-03)
        container.register(SchedulePermissionPromptUseCase.self, scope: .unique) { c in
            SchedulePermissionPromptUseCaseImpl(repository: c.resolve())
        }
    }
}
