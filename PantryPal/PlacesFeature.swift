//
//  PlacesFeature.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//

import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct PlacesFeature {
    
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        // Data
        var places: IdentifiedArrayOf<PlaceFeature.State> = []
        
        // Navigation
        var path = StackState<Path.State>()
        
        // Add-Place sheet UI
        var isAddingPlace = false
        var newPlaceName = ""
        var newPlaceIcon = "shippingbox"   // <- selected icon for new place
    }
    
    // MARK: - Action
    enum Action: BindableAction, Equatable {
        // Bindings for sheet fields
        case binding(BindingAction<State>)
        
        // UX
        case addPlaceButtonTapped
        case confirmAddPlace
        case deletePlaces(IndexSet)
        
        // Persistence / lifecycle
        case loadRequested
        case loadSucceeded([PlaceFeature.State])
        case loadFailed
        
        // Navigation (child routes)
        case path(StackAction<Path.State, Path.Action>)
        
        // Permissions
        case requestNotificationPermission
        case notificationPermissionResponse(Bool)
    }
    
    // MARK: - Dependencies
    @Dependency(\.uuid) var uuid
    @Dependency(\.db) var db   // <- from DBClient.swift
    @Dependency(\.notifications) var notifications
    
    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce<PlacesFeature.State, PlacesFeature.Action> { state, action in
            switch action {
            case .requestNotificationPermission:
                return .run { send in
                    do {
                        let granted = try await notifications.requestAuthorization()
                        await send(.notificationPermissionResponse(granted))
                    } catch {
                        await send(.notificationPermissionResponse(false))
                    }
                }
                
            case .notificationPermissionResponse:
                return .none
                
            case .loadRequested:
                return .run { send in
                    do {
                        let places = try await db.load()
                        await send(.loadSucceeded(places))
                    } catch {
                        await send(.loadFailed)
                    }
                }
                
            case let .loadSucceeded(places):
                state.places = .init(uniqueElements: places)
                return .none
                
            case .loadFailed:
                return .none
                
            case .addPlaceButtonTapped:
                state.isAddingPlace = true
                return .none
                
            case .confirmAddPlace:
                let trimmed = state.newPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                
                let newPlace = PlaceFeature.State(
                    id: uuid(),
                    name: trimmed,
                    iconName: state.newPlaceIcon,
                    items: []
                )
                
                state.places.append(newPlace)
                
                // reset sheet fields
                state.newPlaceName = ""
                state.newPlaceIcon = "shippingbox"
                state.isAddingPlace = false
                
                // persist snapshot
                let snapshot = Array(state.places)
                return .run { _ in
                    try await db.replaceAll(snapshot)
                }
                
                // ---- Delete place (from grid context menu or elsewhere)
            case let .deletePlaces(indexSet):
                for i in indexSet {
                    let id = state.places[i].id
                    _ = state.places.remove(id: id)
                }
                let snapshot = Array(state.places)
                return .run { _ in
                    try await db.replaceAll(snapshot)
                }
                
                // ---- Keep parent in sync with child updates (items added/edited)
            case let .path(.element(id: _, action: .place(.delegate(.updated(child))))):
                state.places[id: child.id] = child
                let snapshot = Array(state.places)
                return .run { _ in
                    try await db.replaceAll(snapshot)
                }
                
            case .path:
                return .none
                
            case .binding:
                return .none
            }
        }
        .forEach(\.path, action: \.path) { Path() }
    }
    
    // MARK: - Navigation destinations
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
