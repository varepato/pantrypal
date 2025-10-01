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

extension FoodItem {
    var isExpired: Bool {
        guard let expirationDate else {
            return false // if no date, treat as not expired
        }
        let today = Calendar.current.startOfDay(for: Date())
        return expirationDate < today
    }
}

