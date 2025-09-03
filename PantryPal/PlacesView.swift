//
//  PlacesView.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//

import SwiftUI
import ComposableArchitecture

struct PlacesView: View {
    @Bindable var store: StoreOf<PlacesFeature>
    init(store: StoreOf<PlacesFeature>) { self.store = store }
    
    var body: some View {
        NavigationStackStore(self.store.scope(state: \.path, action: \.path)) {
            List {
                ForEach(store.places) { place in
                    Button {
                        // Push the place onto the nav stack
                        store.path.append(.place(place))
                    } label: {
                        HStack {
                            Text(place.name)
                            Spacer()
                            Text("\(place.items.count)").foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { store.send(.deletePlaces($0)) }
            }
            .navigationTitle("Places")
            .toolbar {
                Button { store.send(.addPlaceButtonTapped) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Place")
            }
            .sheet(isPresented: $store.isAddingPlace) {
                NavigationStack {
                    Form {
                        TextField("e.g. Pantry, Fridge, Freezer", text: $store.newPlaceName)
                            .textInputAutocapitalization(.words)
                    }
                    .navigationTitle("New Place")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { store.isAddingPlace = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { store.send(.confirmAddPlace) }
                                .disabled(store.newPlaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        } destination: { state in
            switch state {
            case .place:
                CaseLet(/PlacesFeature.Path.State.place,
                         action: PlacesFeature.Path.Action.place,
                         then: PlaceView.init(store:))
            }
        }
    }
}
