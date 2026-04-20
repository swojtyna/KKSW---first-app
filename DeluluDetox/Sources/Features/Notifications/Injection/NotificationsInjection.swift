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
    }
}
