//
//  PersistenceModels.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 4/09/25.
//

// PersistenceModels.swift
import Foundation
import SwiftData

@Model
final class PlaceStore {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String = "#3B82F6"
    // delete a place → delete its items
    @Relationship(deleteRule: .cascade, inverse: \FoodItemStore.place)
    var items: [FoodItemStore] = []
    
    init(id: UUID = UUID(), name: String, iconName: String, colorHex: String = "#3B82F6") {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }
}

@Model
final class FoodItemStore {
    var id: UUID
    var name: String
    var quantity: Int
    var notes: String?
    var expirationDate: Date?
    var place: PlaceStore?
    
    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int,
        notes: String? = nil,
        expirationDate: Date? = nil,
        place: PlaceStore? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.notes = notes
        self.expirationDate = expirationDate
        self.place = place
    }
}


@Model
final class ShoppingListItemStore {
    @Attribute(.unique) var id: UUID
    var name: String                    // user-facing label
    var desiredQuantity: Int            // default 1
    var notes: String?                  // optional user notes
    var source: Source                  // .expiredCleanup / .depleted / .manual
    var linkedFoodItemID: UUID?         // origin FoodItemStore (optional)
    var normalizedKey: String           // lowercased trimmed; for de-dupe
    var status: Status                  // .toBuy / .purchased
    var createdAt: Date
    var updatedAt: Date
    var lastPlaceID: UUID?
    
    enum Source: String, Codable, Hashable { case expiredCleanup, depleted, manual }
    enum Status: String, Codable, Hashable { case toBuy, purchased }
    
    init(
        id: UUID = UUID(),
        name: String,
        desiredQuantity: Int = 1,
        notes: String? = nil,
        source: Source,
        linkedFoodItemID: UUID? = nil,
        status: Status = .toBuy,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastPlaceID: UUID? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.desiredQuantity = max(1, desiredQuantity)
        self.notes = notes
        self.source = source
        self.linkedFoodItemID = linkedFoodItemID
        self.normalizedKey = Self.normalizeKey(name)
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastPlaceID = lastPlaceID
    }
    
    static func normalizeKey(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
