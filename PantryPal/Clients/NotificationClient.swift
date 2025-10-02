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
                let cal = Calendar.current
                let tz = TimeZone.current
                
                // Fire at 9:00 AM local time on fireDate’s day
                let ymd = cal.dateComponents(in: tz, from: fireDate)
                var comps = DateComponents()
                comps.year = ymd.year
                comps.month = ymd.month
                comps.day = ymd.day
                comps.hour = 9
                comps.minute = 0
                comps.second = 0
                comps.timeZone = tz
                
                guard let fire = cal.date(from: comps) else { return }
                let now = Date()
                
                // Guard 1: skip if fire time is in the past (prevents “deliver now”)
                if fire <= now {
                    await center.removePendingNotificationRequests(withIdentifiers: [id])
                    return
                }
                
                // De-dup: remove any pending with same id before adding
                await center.removePendingNotificationRequests(withIdentifiers: [id])
                
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

/// Stable IDs so we can cancel/reschedule cleanly.
enum NotifID {
  static func pre(_ id: UUID) -> String { "pp.pre.\(id.uuidString)" }
  static func exp(_ id: UUID) -> String { "pp.exp.\(id.uuidString)" }
}

/// Schedules a pre-alert N days before and a day-of alert, both non-repeating.
/// Assumes your domain type `FoodItem` has `id`, `name`, and `expirationDate`.
enum PantryNotifs {
  static func scheduleForItem(
    _ item: FoodItem,
    preDays: Int = 3,
    hour: Int = 9,
    notifications: NotificationsClient
  ) async {
    // If no expiration, just ensure no pending notifs remain.
    guard let exp = item.expirationDate else {
      await notifications.cancel([NotifID.pre(item.id), NotifID.exp(item.id)])
      return
    }

    let cal = Calendar.current
    let startOfExp = cal.startOfDay(for: exp)
    let preDate = cal.date(byAdding: .day, value: -preDays, to: startOfExp) ?? startOfExp

    // Compose the two fire dates at the chosen hour (local tz handled in client).
    let preFire  = cal.date(bySettingHour: hour, minute: 0, second: 0, of: preDate)  ?? preDate
    let expFire  = cal.date(bySettingHour: hour, minute: 0, second: 0, of: startOfExp) ?? startOfExp

    // Cancel old requests for this item (both IDs), then schedule guarded.
    await notifications.cancel([NotifID.pre(item.id), NotifID.exp(item.id)])

    let df = DateFormatter()
    df.dateStyle = .medium
    let expText = df.string(from: exp)

    // Pre-alert (will be skipped by client if in the past)
    try? await notifications.schedule(
      NotifID.pre(item.id),
      "Expiring soon",
      "\(item.name) expires on \(expText).",
      preFire
    )

    // Day-of (also skipped by client if already past)
    try? await notifications.schedule(
      NotifID.exp(item.id),
      "Expired today",
      "\(item.name) expires today.",
      expFire
    )
  }

  /// Optional utility to rebuild notifications for all items (e.g., after import/migration).
  static func rescheduleAll(places: [PlaceFeature.State], notifications: NotificationsClient) async {
    for place in places {
      for item in place.items {
        await scheduleForItem(item, notifications: notifications)
      }
    }
  }
}
