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
            
            ScrollView {
                VStack(spacing: 12) {
                    if expiredTotal > 0 && canShowExpired {
                        StatusBanner(
                            kind: .expired,
                            count: expiredTotal,
                            onTap: {
                                let rows = buildExpirationRows(kind: .expired, places: store.places)
                                store.path.append(.expiration(.init(kind: .expired, rows: rows)))
                            },
                            onClose: {
                                store.send(.dismissBanner(.expired))
                            }
                        )
                    }
                    
                    if soonTotal > 0 && canShowSoon {
                        StatusBanner(
                            kind: .expiringSoon,
                            count: soonTotal,
                            onTap: {
                                let rows = buildExpirationRows(kind: .expiringSoon(days: 3), places: store.places)
                                store.path.append(.expiration(.init(kind: .expiringSoon(days: 3), rows: rows)))
                            },
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
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    AddFAB { store.send(.addPlaceButtonTapped) }
                        .padding(.trailing, 24)
                }
                .padding(.bottom, 8)   // space above the home indicator
                .background(.clear)
            }

            .navigationTitle("PantryNeat")
            .task {
                store.send(.loadRequested)
                store.send(.requestNotificationPermission)
            }
        } destination: { state in
            switch state {
            case .place:
              CaseLet(/PlacesFeature.Path.State.place,
                      action: PlacesFeature.Path.Action.place,
                      then: PlaceView.init(store:))

            case .expiration:
              CaseLet(/PlacesFeature.Path.State.expiration,
                      action: PlacesFeature.Path.Action.expiration) { store in
                ExpirationView(store: store)
              }
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

