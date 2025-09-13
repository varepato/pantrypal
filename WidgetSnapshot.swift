//
//  WidgetSnapshot.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 11/09/25.
//

import Foundation

enum AppGroup {
    static let id = "group.VALMAD.PantryPal"
}

public struct WidgetSnapshot: Codable {
    public let totalItems: Int
    public let expiringSoon: Int
    public let expired: Int
    public let updatedAt: Date
}

enum WidgetSnapshotStore {
    private static let suite = UserDefaults(suiteName: AppGroup.id)!
    private static let key   = "widget.snapshot.v1"

    static func save(_ snapshot: WidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            suite.set(data, forKey: key)
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let data = suite.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

