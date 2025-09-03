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
                let placesArray: [PlaceFeature.State] = Array(store.places.elements)
                
                ForEach(placesArray, id: \.id) { place in
                    Button {
                        store.path.append(.place(place))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: place.iconName)
                                .imageScale(.large)
                                .frame(width: 28, height: 28)
                            Text(place.name)
                            Spacer()
                            Text("\(place.items.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in store.send(.deletePlaces(indexSet)) }
            }
            .navigationTitle("Places")
            .toolbar {
                Button { store.send(.addPlaceButtonTapped) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Place")
            }
            .sheet(isPresented: $store.isAddingPlace) {
                AddPlaceSheet(
                    name: $store.newPlaceName,
                    iconName: $store.newPlaceIcon,    // <— Bind to state
                    isPresented: $store.isAddingPlace,
                    onConfirm: { store.send(.confirmAddPlace) }
                )
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

private struct AddPlaceSheet: View {
    @Binding var name: String
    @Binding var iconName: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    
    // A small curated set of useful SF Symbols.
    private let iconOptions: [String] = [
        // Containers / storage
        "shippingbox",
        "archivebox",
        "cabinet",
        "tray",
        "tray.full",
        "air.conditioner.horizontal",
        "frying.pan",
        "refrigerator",
        "sink",
        "oven",
        "popcorn",
        "door.right.hand.closed",
        "door.sliding.left.hand.closed",
        "door.garage.closed",
        
        // Kitchen / food
        "takeoutbag.and.cup.and.straw",
        "cart",
        "basket",
        "fork.knife",
        "birthday.cake",
        "wineglass",
        "cup.and.saucer",
        "carrot",
        "leaf",
        
        // Generic / utility
        "tag",
        "barcode.viewfinder",
        "list.bullet",
        "list.bullet.clipboard",
        "square.stack",
        "square.stack.3d.up"
    ]
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Place name (e.g., Pantry, Fridge, Freezer)", text: $name)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Icon") {
                    IconPicker(iconName: $iconName, options: iconOptions)
                }
            }
            .navigationTitle("New Place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onConfirm() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct IconPicker: View {
    @Binding var iconName: String
    let options: [String]
    
    // small grid, simple to type-check
    private let cols = [GridItem(.adaptive(minimum: 44), spacing: 12)]
    
    var body: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(options, id: \.self) { symbol in
                Button {
                    iconName = symbol
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: symbol)
                            .imageScale(.large)
                            .frame(width: 32, height: 32)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(symbol == iconName ? Color.accentColor : Color.secondary.opacity(0.3),
                                            lineWidth: symbol == iconName ? 2 : 1)
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
