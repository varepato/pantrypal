//
//  PlaceView.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//
import SwiftUI
import ComposableArchitecture

struct PlaceView: View {
    @Bindable var store: StoreOf<PlaceFeature>
    init(store: StoreOf<PlaceFeature>) { self.store = store }
    
    var body: some View {
        List {
            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "carrot")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    Text("No items here")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("Use the + button to add food.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding()
                .listRowBackground(Color.clear)  // keeps background clean
            } else {
                ForEach(store.items) { (item: FoodItem) in
                    FoodItemRow(
                        item: item,
                        onQtyChange: { (newQty: Int) in
                            let id = item.id
                            store.send(.quantityChanged(id: id, qty: newQty))
                        }
                    )
                }
                .onDelete { store.send(.deleteItems($0)) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                AddFAB { store.send(.addItemButtonTapped) }
                    .padding(.trailing, 24)
            }
            .padding(.bottom, 8)   // space above the home indicator
            .background(.clear)
        }
        .navigationTitle(store.name)
        .sheet(isPresented: $store.isAddingItem) {
            AddFoodItemSheet(
                name: $store.newItemName,
                qty: $store.newItemQty,
                notes: $store.newItemNotes,
                expiry: $store.newItemExpiry,
                isPresented: $store.isAddingItem,
                onConfirm: { store.send(.confirmAddItem) }
            )
        }
    }
}

private struct FoodItemRow: View {
    let item: FoodItem
    let onQtyChange: (Int) -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                // Name + quantity inline
                HStack(spacing: 8) {
                    Text(item.name).font(.headline)
                    Text("• \(item.quantity)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let label = expiryLabel() {
                    Text(label.text)
                        .font(.caption)
                        .foregroundStyle(label.color)
                }
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Quick quantity stepper (optional; keeps list interactive)
            Stepper(
                value: Binding<Int>(
                    get: { item.quantity },
                    set: { onQtyChange($0) }
                ),
                in: 0...999
            ) { EmptyView() }
                .labelsHidden()
        }
    }
    
    private func expiryLabel() -> (text: String, color: Color)? {
        guard let days = item.daysUntilExpiry else { return nil }
        if days < 0 { return ("Expired \(abs(days))d", .red) }
        if days == 0 { return ("Expires today", .orange) }
        if days <= 7 { return ("Expires in \(days)d", .orange) }
        return ("Expires in \(days)d", .secondary)
    }
}
