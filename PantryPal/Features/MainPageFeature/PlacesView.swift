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
                    
                    if store.places.isEmpty {
                      VStack(spacing: 8) {
                        Image(systemName: "tray")
                          .font(.system(size: 50))
                          .foregroundStyle(.secondary)

                        Text("No places yet")
                          .font(.headline)
                          .foregroundStyle(.secondary)

                        Text("Tap the + button to add a place.")
                          .font(.subheadline)
                          .foregroundStyle(.secondary)
                          .multilineTextAlignment(.center)
                      }
                      .frame(maxWidth: .infinity, minHeight: 300)
                      .padding()
                    } else {
                        PlacesGrid(
                            places: allPlaces,
                            onTap: { place in store.path.append(.place(place)) },
                            onDelete: { id in if let i = store.places.firstIndex(where: { $0.id == id }) {
                                store.send(.deletePlaces(IndexSet(integer: i)))
                            }}
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 24)
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
            .navigationTitle("Pantry Neat")
            .toolbar {
              ToolbarItem(placement: .topBarTrailing) {
                CartBadgeButton(count: store.shoppingBadge) {
                  store.send(.shoppingButtonTapped)
                }
              }
            }
            .task {
                store.send(.loadRequested)
                store.send(.requestNotificationPermission)
                store.send(.refreshShoppingBadge)
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
            case .shoppingList:
              CaseLet(/PlacesFeature.Path.State.shoppingList,
                      action: PlacesFeature.Path.Action.shoppingList) { store in
                ShoppingListView(store: store)
              }
            }
        }
        .sheet(isPresented: $store.isAddingPlace) {
            AddPlaceSheet(
                name: $store.newPlaceName,
                iconName: $store.newPlaceIcon,
                isPresented: $store.isAddingPlace,
                colorHex: $store.newPlaceColorHex,
                onConfirm: { store.send(.confirmAddPlace) }
            )
        }
    }
}

private struct CartBadgeButton: View {
  let count: Int
  let tap: () -> Void
  var body: some View {
    Button(action: tap) {
      ZStack(alignment: .topTrailing) {
        Image(systemName: "cart")
        if count > 0 {
          Text("\(min(99, count))")
            .font(.caption2).bold()
            .padding(4)
            .background(Circle().fill(Color.red))
            .foregroundStyle(.white)
            .offset(x: 8, y: -8)
        }
      }
      .accessibilityLabel("Shopping List, \(count) items")
    }
  }
}
