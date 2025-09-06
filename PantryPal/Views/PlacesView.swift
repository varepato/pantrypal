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
            PlacesGrid(
                places: Array(store.places.elements),
                onTap: { place in
                    store.path.append(.place(place))
                },
                onDelete: { id in
                    if let idx = store.places.firstIndex(where: { $0.id == id }) {
                        store.send(.deletePlaces(IndexSet(integer: idx)))
                    }
                }
            )
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

private struct PlacesGrid: View {
    let places: [PlaceFeature.State]
    let onTap: (PlaceFeature.State) -> Void
    let onDelete: (PlaceFeature.State.ID) -> Void
    
    // explicit columns to help the type-checker
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(places, id: \.id) { place in
                    let hasExpired = place.items.elements.contains { ($0.daysUntilExpiry ?? 1) < 0 }
                    let hasExpiringSoon = place.items.elements.contains { isExpiringSoon(expiration: $0.expirationDate, within: 3) }
                    PlaceCard(
                        place: place,
                        hasExpiringSoon: hasExpiringSoon,
                        hasExpired: hasExpired,
                        onTap: { onTap(place) },
                        onDelete: { onDelete(place.id) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }
    
    public func daysUntil(_ date: Date?) -> Int? {
        guard let date else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }
    
    public func isExpiringSoon(expiration: Date?, within days: Int = 3) -> Bool {
        guard let d = daysUntil(expiration) else { return false }
        return d >= 0 && d <= days
    }
}

private struct PlaceCard: View {
    let place: PlaceFeature.State
    let hasExpiringSoon: Bool
    let hasExpired: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: place.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .padding(.top, 12)
                    .tint(Color.accentColor)
                
                Text(place.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Text("\(place.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, minHeight: 120) // consistent card height
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if hasExpired || hasExpiringSoon {
                    Circle()
                        .fill(hasExpired ? Color.red : Color.orange)
                        .frame(width: 10, height: 10)
                        .offset(x: -8, y: 8)
                        .accessibilityLabel(hasExpired ? "Has expired items" : "Has expiring items")
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
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
        "snowflake",
        
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

