//
//  PlaceFeature.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//
import SwiftUI
import ComposableArchitecture

@Reducer
struct PlaceFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: UUID
        var name: String
        var items: IdentifiedArrayOf<FoodItem> = []
        var colorHex: String = "#3B82F6"
        var iconName: String = "shippingbox"
        var searchQuery: String = ""
        
        // UI state for "Add item"
        var isAddingItem = false
        var newItemName = ""
        var newItemQty = 1
        var newItemNotes = ""
        var newItemExpiry: Date? = nil
        
        init(
            id: UUID,
            name: String,
            iconName: String,
            colorHex: String,
            items: IdentifiedArrayOf<FoodItem> = []
        ) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.colorHex = colorHex
            self.items = items
        }
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        
        case addItemButtonTapped
        case confirmAddItem
        case deleteItems(IndexSet)
        case quantityChanged(id: FoodItem.ID, qty: Int)
        case setItemExpiry(id: FoodItem.ID, date: Date?)
        
        // Lets child notify parent so the main list stays in sync.
        enum Delegate: Equatable { case updated(State) }
        case delegate(Delegate)
    }
    
    @Dependency(\.uuid) var uuid
    @Dependency(\.notifications) var notifications
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        ComposableArchitecture.Reduce<PlaceFeature.State, PlaceFeature.Action> {
            (state: inout PlaceFeature.State, action: PlaceFeature.Action) in
            
            switch action {
            case .addItemButtonTapped:
                state.isAddingItem = true
                return Effect<PlaceFeature.Action>.none
                
            case .confirmAddItem:
                let trimmed = state.newItemName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return Effect<PlaceFeature.Action>.none }
                
                state.items.append(
                    FoodItem(
                        id: uuid(),
                        name: trimmed,
                        quantity: state.newItemQty,
                        notes: state.newItemNotes.isEmpty ? nil : state.newItemNotes,
                        expirationDate: state.newItemExpiry
                    )
                )
                // reset fields
                state.isAddingItem = false
                state.newItemName = ""
                state.newItemQty = 1
                state.newItemNotes = ""
                state.newItemExpiry = nil
                
                if let exp = state.items.last?.expirationDate {   // the item you just appended
                    let item = state.items.last!
                    let id = "item-\(item.id.uuidString)"
                    let fire = reminderDate(for: exp, leadDays: 2) // customize lead time
                    return .merge(
                        .send(.delegate(.updated(state))),            // keep your existing delegate
                        .run { _ in
                            try await notifications.schedule(
                                id,
                                "Expiring soon: \(item.name)",
                                "Expires on \(DateFormatter.localizedString(from: exp, dateStyle: .medium, timeStyle: .none))",
                                fire
                            )
                        }
                    )
                }
                return .send(.delegate(.updated(state)))
                
            case let .setItemExpiry(id, date):
                state.items[id: id]?.expirationDate = date
                
                let snapshot = state // capture to send to parent
                let itemId = "item-\(id.uuidString)"
                
                if let exp = date {
                    let name = state.items[id: id]?.name ?? "Item"
                    let fire = reminderDate(for: exp, leadDays: 2)
                    return .merge(
                        .send(.delegate(.updated(snapshot))),
                        .run { _ in
                            // re-schedule (add replaces with same identifier)
                            try await notifications.schedule(
                                itemId,
                                "Expiring soon: \(name)",
                                "Expires on \(DateFormatter.localizedString(from: exp, dateStyle: .medium, timeStyle: .none))",
                                fire
                            )
                        }
                    )
                } else {
                    // no longer has an expiration → cancel any pending notification
                    return .merge(
                        .send(.delegate(.updated(snapshot))),
                        .run { _ in await notifications.cancel([itemId]) }
                    )
                }
                
            case let .deleteItems(offsets):
                // collect IDs to cancel
                let idsToCancel = offsets.compactMap { idx in state.items[safe: idx]?.id.uuidString }
                    .map { "item-\($0)" }
                
                for i in offsets {
                    let id = state.items[i].id
                    _ = state.items.remove(id: id)
                }
                
                return .merge(
                    .send(.delegate(.updated(state))),
                    .run { _ in await notifications.cancel(idsToCancel) }
                )
                
            case let .quantityChanged(id, qty):
                state.items[id: id]?.quantity = max(0, qty)
                return Effect<PlaceFeature.Action>.send(.delegate(.updated(state)))
                
            case .binding, .delegate:
                return Effect<PlaceFeature.Action>.none
            }
        }
    }
    
    private func reminderDate(for expiration: Date, leadDays: Int = 2) -> Date {
        Calendar.current.date(byAdding: .day, value: -leadDays, to: expiration) ?? expiration
    }
    
}

extension RandomAccessCollection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

extension PlaceFeature.State {
    func expiredCount() -> Int {
        items.elements.filter { isExpired($0.expirationDate) }.count
    }
    func expiringSoonCount(within days: Int = 3) -> Int {
        items.elements.filter { isExpiringSoon($0.expirationDate, within: days) }.count
    }
}
