//
//  NotificationClient.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 5/09/25.
//

import Foundation
import UserNotifications
import ComposableArchitecture

struct NotificationsClient {
    var requestAuthorization: @Sendable () async throws -> Bool
    var schedule: @Sendable (_ id: String, _ title: String, _ body: String, _ fireDate: Date) async throws -> Void
    var cancel: @Sendable (_ ids: [String]) async -> Void
}

extension DependencyValues {
    var notifications: NotificationsClient {
        get { self[NotificationsClient.self] }
        set { self[NotificationsClient.self] = newValue }
    }
}

extension NotificationsClient: DependencyKey {
    static var liveValue: Self {
        .init(
            requestAuthorization: {
                try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
            },
            schedule: { id, title, body, fireDate in
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                
                // fire at 9:00 AM local time on fireDate’s day (feel free to change)
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
                comps.hour = 9; comps.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                
                try await UNUserNotificationCenter.current().add(request)
            },
            cancel: { ids in
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            }
        )
    }
}
