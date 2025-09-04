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
        var iconName: String = "shippingbox"
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
            items: IdentifiedArrayOf<FoodItem> = []
        ) {
            self.id = id
            self.name = name
            self.iconName = iconName
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
                
                return Effect<PlaceFeature.Action>.send(.delegate(.updated(state)))

            case let .setItemExpiry(id, date):
                state.items[id: id]?.expirationDate = date
                return Effect<PlaceFeature.Action>.send(.delegate(.updated(state)))
                
            case let .deleteItems(offsets):
                for index in offsets {
                    let id = state.items[index].id
                    _ = state.items.remove(id: id)
                }
                return Effect<PlaceFeature.Action>.send(.delegate(.updated(state)))
                
            case let .quantityChanged(id, qty):
                state.items[id: id]?.quantity = max(0, qty)
                return Effect<PlaceFeature.Action>.send(.delegate(.updated(state)))
                
            case .binding, .delegate:
                return Effect<PlaceFeature.Action>.none
            }
        }
    }
}
