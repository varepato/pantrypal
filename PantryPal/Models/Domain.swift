//
//  Domain.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//
import Foundation
import ComposableArchitecture

struct FoodItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var quantity: Int = 1
    var notes: String? = nil
    var expirationDate: Date? = nil
    
    var daysUntilExpiry: Int? {
        guard let d = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: d).day
    }
}

struct PlaceSnapshot: Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var iconName: String = "shippingbox"
    var colorHex: String = "#3B82F6"
    var items: IdentifiedArrayOf<FoodItem> = []
}

struct ShoppingListItemDTO: Equatable, Identifiable {
    var id: UUID
    var name: String
    var desiredQuantity: Int
    var notes: String?
    enum Source: Equatable { case expiredCleanup, depleted, manual }
    enum Status: Equatable { case toBuy, purchased }
    var source: Source
    var status: Status
    var linkedFoodItemID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var lastPlaceID: UUID?
}

extension ShoppingListItemDTO {
    init(model: ShoppingListItemStore) {
        self.id = model.id
        self.name = model.name
        self.desiredQuantity = model.desiredQuantity
        self.notes = model.notes
        self.source = {
            switch model.source {
            case .expiredCleanup: return .expiredCleanup
            case .depleted:       return .depleted
            case .manual:         return .manual
            }
        }()
        self.status = (model.status == .toBuy) ? .toBuy : .purchased
        self.linkedFoodItemID = model.linkedFoodItemID
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.lastPlaceID = model.lastPlaceID
    }
}

extension ShoppingListItemStore {
    func updating(from dto: ShoppingListItemDTO) -> ShoppingListItemStore {
        self.name = dto.name
        self.desiredQuantity = max(1, dto.desiredQuantity)
        self.notes = dto.notes
        self.source = {
            switch dto.source {
            case .expiredCleanup: return .expiredCleanup
            case .depleted:       return .depleted
            case .manual:         return .manual
            }
        }()
        self.status = (dto.status == .toBuy) ? .toBuy : .purchased
        self.linkedFoodItemID = dto.linkedFoodItemID
        self.updatedAt = dto.updatedAt
        self.normalizedKey = ShoppingListItemStore.normalizeKey(dto.name)
        self.lastPlaceID = dto.lastPlaceID  
        return self
    }
}

