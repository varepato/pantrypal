//
//  PlacesFeature.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//
import SwiftUI
import ComposableArchitecture

@Reducer
struct PlacesFeature {
    @ObservableState
    struct State: Equatable {
        var places: IdentifiedArrayOf<PlaceFeature.State> = []
        var path = StackState<Path.State>()   // navigation stack
        var isAddingPlace = false
        var newPlaceName = ""
        var newPlaceIcon = "shippingbox"
    }
    
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case addPlaceButtonTapped
        case confirmAddPlace
        case deletePlaces(IndexSet)
        case path(StackAction<Path.State, Path.Action>)
    }
    
    @Dependency(\.uuid) var uuid
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .addPlaceButtonTapped:
                state.isAddingPlace = true
                return .none
                
            case .confirmAddPlace:
                let trimmed = state.newPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                let newPlace = PlaceFeature.State(
                  id: uuid(),
                  name: trimmed,
                  iconName: state.newPlaceIcon
                )
                state.places.append(newPlace)
                state.newPlaceName = ""
                state.newPlaceIcon = "shippingbox"
                state.isAddingPlace = false
                return .none
                
            case let .deletePlaces(offsets):
                for index in offsets {
                    let id = state.places[index].id
                    _ = state.places.remove(id: id)
                }
                return .none
                
            case .binding:
                return .none
                
            case let .path(.element(id: _, action: .place(.delegate(.updated(child))))):
                // keep the root list in sync with child edits
                state.places[id: child.id] = child
                return .none
                
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) { Path() } // wire children
    }
    
    // MARK: - Destinations in the stack
    @Reducer
    struct Path {
        @ObservableState
        enum State: Equatable {
            case place(PlaceFeature.State)
        }
        enum Action: Equatable {
            case place(PlaceFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: \.place, action: \.place) { PlaceFeature() }
        }
    }
}

