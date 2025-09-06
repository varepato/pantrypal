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

