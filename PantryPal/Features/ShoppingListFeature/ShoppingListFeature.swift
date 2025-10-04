//
//  ShoppingListFeature.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 2/10/25.
//
import Foundation
import SwiftUI
import ComposableArchitecture

struct ShoppingListFeature: Reducer {
    struct State: Equatable {
        var items: [ShoppingListItemDTO] = []
        var isLoading = false
        var error: String?
        @PresentationState var addSheet: AddSheet.State?
    }
    
    enum Action: Equatable {
        case onAppear
        case _loaded([ShoppingListItemDTO])
        case _failed(String)
        case addButtonTapped
        case addSheet(PresentationAction<AddSheet.Action>)
        case setQuantity(id: UUID, qty: Int)
        case delete(IndexSet)
    }
    
    @Dependency(\.db) var db
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setQuantity(id, qty):
              // update UI immediately
              if let idx = state.items.firstIndex(where: { $0.id == id }) {
                state.items[idx].desiredQuantity = max(1, qty)
              }
              // persist
              let item = state.items.first { $0.id == id }!
              return .run { _ in try await db.updateShoppingItem(item) }

            case let .delete(indexSet):
              let ids = indexSet.map { state.items[$0].id }
              state.items.remove(atOffsets: indexSet)
              return .run { _ in try await db.deleteShoppingItems(ids) }

            case .addSheet:
                return .none
            case .addButtonTapped:
                state.addSheet = .init()
                return .none
            case .addSheet(.presented(.confirm(let name, let qty))):
                // create/merge then reload
                state.addSheet = nil 
                return .run { send in
                    _ = try await db.mergeOrCreateShoppingItem(name, max(1, qty), .manual, nil, nil)
                    await send(.onAppear) // simple reload
                }
            case .addSheet(.presented(.cancel)):
              state.addSheet = nil
              return .none

            case .addSheet(.dismiss):
              state.addSheet = nil
              return .none
                
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        let items = try await db.loadShoppingList()
                        await send(._loaded(items))
                    } catch {
                        await send(._failed(String(describing: error)))
                    }
                }
                
            case let ._loaded(items):
                state.isLoading = false
                state.items = items
                return .none
                
            case let ._failed(message):
                state.isLoading = false
                state.error = message
                return .none
            }
        }.ifLet(\.$addSheet, action: /Action.addSheet) { AddSheet() }
    }
}

extension ShoppingListFeature {
    struct AddSheet: Reducer {
        struct State: Equatable { var name = ""; var qty = 1 }
        enum Action: Equatable {
            case setName(String)
            case setQty(Int)
            case confirm(String, Int)
            case cancel
        }
        var body: some ReducerOf<Self> { Reduce { _, _ in .none } }
    }
}


