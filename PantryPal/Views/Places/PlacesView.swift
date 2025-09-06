//
//  PlacesView.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct PlacesView: View {
    @Bindable var store: StoreOf<PlacesFeature>
    init(store: StoreOf<PlacesFeature>) { self.store = store }
    
    var body: some View {
        // Break type inference: create the nav store up front
        let navStore: Store<StackState<PlacesFeature.Path.State>, StackAction<PlacesFeature.Path.State, PlacesFeature.Path.Action>> =
        store.scope(state: \.path, action: \.path)
        
        NavigationStackStore(navStore) {
            // content
            // Features/Places/PlacesView.swift (inside the main content closure)
            let allPlaces = Array(store.places.elements)
            let expiredTotal = allPlaces.reduce(0) { $0 + $1.expiredCount() }
            let soonTotal    = allPlaces.reduce(0) { $0 + $1.expiringSoonCount(within: 3) }
            
            let now = Date()
            let canShowExpired = store.hideExpiredBannerUntil.map { now >= $0 } ?? true
            let canShowSoon    = store.hideExpiringBannerUntil.map { now >= $0 } ?? true
            
            VStack(spacing: 12) {
                if expiredTotal > 0 && canShowExpired {
                    StatusBanner(
                        kind: .expired,
                        count: expiredTotal,
                        onTap: {
                            // TODO: navigate to a filtered view (e.g., a "Smart list: Expired")
                            print("tapping banner")
                        },
                        onClose: {
                            print("tapping close banner")
                            store.send(.dismissBanner(.expired))
                        }
                    )
                }
                
                if soonTotal > 0 && canShowSoon {
                    StatusBanner(
                        kind: .expiringSoon,
                        count: soonTotal,
                        onTap: { /* navigate to expiring filter */ },
                        onClose: { store.send(.dismissBanner(.expiringSoon)) }
                    )
                }
                
                // your grid below
                PlacesGrid(
                    places: allPlaces,
                    onTap: { place in store.path.append(.place(place)) },
                    onDelete: { id in if let i = store.places.firstIndex(where: { $0.id == id }) {
                        store.send(.deletePlaces(IndexSet(integer: i)))
                    }}
                )
            }
            .padding(.horizontal)
            .padding(.top, 12)

            .navigationTitle("Pantry Pal")
            .task {
                store.send(.loadRequested)
                store.send(.requestNotificationPermission)
            }
            .toolbar {
                Button { store.send(.addPlaceButtonTapped) } label: {
                    Image(systemName: "plus")
                }
            }
        } destination: { state in
            switch state {
            case .place:
                CaseLet(
                    /PlacesFeature.Path.State.place,
                     action: PlacesFeature.Path.Action.place,
                     then: PlaceView.init(store:)
                )
            }
        }
        // keep the sheet outside the NavigationStackStore closure
        .sheet(isPresented: $store.isAddingPlace) {
            AddPlaceSheet(
                name: $store.newPlaceName,
                iconName: $store.newPlaceIcon,
                isPresented: $store.isAddingPlace,
                onConfirm: { store.send(.confirmAddPlace) }
            )
        }
    }
}

