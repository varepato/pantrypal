import Foundation
import BackgroundTasks
import SwiftData
import WidgetKit

enum BackgroundRefresh {
  static let id = "VALMAD.PantryPal.refresh"

  // Call this once in PantryApp.init()
    static func register() {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
        if let task = task as? BGAppRefreshTask {
          handle(task)                 // OK: correct type
        } else {
          task.setTaskCompleted(success: false)
        }
      }
    }

  // Call this when app moves to background (you already wired onChange)
  static func schedule() {
    let req = BGAppRefreshTaskRequest(identifier: id)
    req.earliestBeginDate = next3amLocal()
    try? BGTaskScheduler.shared.submit(req)
  }

  // ---- Core work (no TCA) ----
  static func handle(_ task: BGAppRefreshTask) {
    // Always reschedule so it keeps recurring
    schedule()

    let work = Task {
      do {
        // 1) Open your SwiftData store (default location)
        //    If you later move to an App Group DB, swap to a ModelConfiguration(url: ...)
        let container = try ModelContainer(for: PlaceStore.self, FoodItemStore.self)
        let context = ModelContext(container)

        // 2) Fetch items
        let items = try context.fetch(FetchDescriptor<FoodItemStore>())

        // 3) Compute counts
        let now = Calendar.current.startOfDay(for: Date())
        func daysUntil(_ date: Date?) -> Int? {
          guard let d = date else { return nil }
          return Calendar.current.dateComponents([.day], from: now, to: Calendar.current.startOfDay(for: d)).day
        }

        let total = items.reduce(0) { $0 + max(0, $1.quantity) }
        let soonWindow = 3
        let expiringSoon = items.filter {
          guard let d = daysUntil($0.expirationDate) else { return false }
          return (0...soonWindow).contains(d)
        }.count
        let expired = items.filter { (daysUntil($0.expirationDate) ?? .max) < 0 }.count

        // 4) Save snapshot to the shared UserDefaults
        let snapshot = WidgetSnapshot(
          totalItems: total,
          expiringSoon: expiringSoon,
          expired: expired,
          updatedAt: Date()
        )
        WidgetSnapshotStore.save(snapshot)

        // 5) Ask WidgetKit to refresh
        WidgetCenter.shared.reloadAllTimelines()

        task.setTaskCompleted(success: true)
      } catch {
        task.setTaskCompleted(success: false)
      }
    }

    task.expirationHandler = { work.cancel() }
  }

  private static func next3amLocal() -> Date {
    let cal = Calendar.current
    let now = Date()
    return cal.nextDate(after: now,
                        matching: DateComponents(hour: 3, minute: 0, second: 0),
                        matchingPolicy: .nextTime) ?? now.addingTimeInterval(6 * 3600)
  }
}

