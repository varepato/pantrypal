//
//  WidgetDataWriter.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 11/09/25.
//

import Foundation
import WidgetKit

/// Adjust if you want a different window.
private let soonDaysWindow = 3

enum WidgetSnapshotWriter {
    static func saveFromPlaces(_ places: [PlaceFeature.State]) {
        // Flatten to domain items
        let items = places.flatMap { $0.items }

        let total = items.reduce(0) { $0 + max(0, $1.quantity) }

        let expiringSoon = items.filter {
            guard let d = $0.daysUntilExpiry else { return false }
            return (0...soonDaysWindow).contains(d)
        }.count

        let expired = items.filter {
            ($0.daysUntilExpiry ?? .max) < 0
        }.count

        let snap = WidgetSnapshot(
            totalItems: total,
            expiringSoon: expiringSoon,
            expired: expired,
            updatedAt: Date()
        )
        WidgetSnapshotStore.save(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

