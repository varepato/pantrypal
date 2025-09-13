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
        var newPlaceColorHex: String = "#3B82F6"
        
        // Banner
        var hideExpiredBannerUntil: Date? = nil
        var hideExpiringBannerUntil: Date? = nil
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
        
        // Banner
        enum BannerKind: Equatable { case expired, expiringSoon }
        case dismissBanner(BannerKind)
        
        // Deeplink
        case openAllItems
        case bannerTapped(BannerKind)
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
            case .openAllItems:
                return .none
            
            case let .bannerTapped(kind):
                switch kind {
                case .expired:
                    let rows = buildExpirationRows(kind: .expired, places: state.places)
                    state.path.append(.expiration(.init(kind: .expired, rows: rows)))
                case .expiringSoon:
                    let rows = buildExpirationRows(kind: .expiringSoon(days: 3), places: state.places)
                    state.path.append(.expiration(.init(kind: .expiringSoon(days: 3), rows: rows)))
                }
                return .none
                
            case let .dismissBanner(kind):
                let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(60*60*24)
                switch kind {
                case .expired:
                    print("hide expired")
                    state.hideExpiredBannerUntil = tomorrow
                case .expiringSoon:
                    print("hide expiring soon")
                    state.hideExpiringBannerUntil = tomorrow
                }
                return .none
                
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
                    colorHex: state.newPlaceColorHex,
                    items: []
                )
                
                state.places.append(newPlace)
                
                // reset sheet fields
                state.newPlaceName = ""
                state.newPlaceIcon = "shippingbox"
                state.isAddingPlace = false
                state.newPlaceColorHex = "#3B82F6"
                
                sortPlaces(&state.places)
                // persist snapshot
                let snapshot = Array(state.places)
                return .run { _ in
                    do { try await db.replaceAll(snapshot) }
                    catch { print("DB save failed:", error) }
                }
                
                // ---- Delete place (from grid context menu or elsewhere)
            case let .deletePlaces(indexSet):
                for i in indexSet {
                    let id = state.places[i].id
                    _ = state.places.remove(id: id)
                }
                sortPlaces(&state.places)
                let snapshot = Array(state.places)
                return .run { _ in
                    try await db.replaceAll(snapshot)
                }
                
            case let .path(.element(id: _, action: .place(.delegate(.updated(child))))):
                state.places[id: child.id] = child
                sortPlaces(&state.places)
                let snapshot = Array(state.places)
                return .run { _ in
                    try await db.replaceAll(snapshot)
                }
                
            case let .path(.element(id: elementID, action: .expiration(.delegate(.cleanupExpired)))):
                
                // Remove all expired items from every place
                for idx in state.places.indices {
                    state.places[idx].items.removeAll { item in
                        let d = item.expirationDate.flatMap {
                            Calendar.current.dateComponents([.day], from: Date(), to: $0).day
                        }
                        return (d ?? 1) < 0
                    }
                }
                
                // pop the view
                state.path.pop(from: elementID)
                sortPlaces(&state.places)
                
                // Persist the new snapshot
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
            case expiration(ExpirationFeature.State)
        }
        enum Action: Equatable {
            case place(PlaceFeature.Action)
            case expiration(ExpirationFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: \.place, action: \.place) { PlaceFeature() }
            Scope(state: \.expiration, action: \.expiration) { ExpirationFeature() }
        }
    }
    
    private func sortPlaces(_ places: inout IdentifiedArrayOf<PlaceFeature.State>) {
        places.sort { a, b in
            let cmp = a.name.localizedCaseInsensitiveCompare(b.name)
            if cmp == .orderedSame { return a.id.uuidString < b.id.uuidString } // stable tie-breaker
            return cmp == .orderedAscending
        }
    }
    
}

