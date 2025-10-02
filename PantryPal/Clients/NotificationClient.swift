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
                let center = UNUserNotificationCenter.current()

                // Build the “9:00 AM on fireDate’s day” time
                var comps = DateComponents()
                let cal = Calendar.current
                let tz = TimeZone.current
                let ymd = cal.dateComponents(in: tz, from: fireDate) // preserves local day
                comps.year = ymd.year
                comps.month = ymd.month
                comps.day = ymd.day
                comps.hour = 9
                comps.minute = 0
                comps.timeZone = tz

                // Turn back into an absolute Date to compare against now
                guard let fire = cal.date(from: comps) else { return }
                let now = Date()

                // ✅ Guard 1: if it’s in the past, DON’T schedule (and clear any stale pending with same id)
                if fire <= now {
                    await center.removePendingNotificationRequests(withIdentifiers: [id])
                    // Optional: print/log to see when this happens
                    // print("Skipped scheduling '\(id)' because fire=\(fire) is in the past.")
                    return
                }

                // Clean up any existing request for this id
                await center.removePendingNotificationRequests(withIdentifiers: [id])

                // Build request
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

                try await center.add(request)
            },
            cancel: { ids in
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            }
        )
    }
}
