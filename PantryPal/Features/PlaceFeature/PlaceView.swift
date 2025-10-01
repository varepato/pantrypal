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
        let query = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // sort first, then filter by name
        let visibleItems = store.items
            .sorted { a, b in
                let ka = sortKey(for: a), kb = sortKey(for: b)
                if ka.group != kb.group { return ka.group < kb.group }
                if ka.days  != kb.days  { return ka.days  < kb.days  }
                return ka.name < kb.name
            }
            .filter { query.isEmpty || $0.name.lowercased().contains(query) }

        var list = List {
            if visibleItems.isEmpty {
                // Empty state for this search
                VStack(spacing: 8) {
                    if query.isEmpty {
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
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No results for “\(store.searchQuery)”")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleItems) { item in
                    FoodItemRow(
                        item: item,
                        onQtyChange: { newQty in
                            store.send(.quantityChanged(id: item.id, qty: newQty))
                        }
                    )
                }
                .onDelete { store.send(.deleteItems($0)) }
            }
        }
        Group {
            if store.items.isEmpty {
                list
            } else {
                list.searchable(
                    text: $store.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search items"
                )
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if store.withState(\.expiredCountValue) > 0 {
                    Button("Clean up (\(store.withState(\.expiredCountValue)))", role: .destructive) {
                        store.send(.cleanUpExpiredTapped)
                    }
                }
            }
        }
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
    
    private func sortKey(for item: FoodItem) -> (group: Int, days: Int, name: String) {
        // daysUntil: negative = expired, 0..N = future, nil = unknown
        let du = item.expirationDate.flatMap { Calendar.current.dateComponents([.day], from: Date(), to: $0).day }
        
        switch du {
        case let d? where d < 0:
            // Group 0: expired — most overdue first (more negative first)
            return (0, d, item.name.lowercased())
        case let d?:
            // Group 1: has date in future — sooner first
            return (1, d, item.name.lowercased())
        default:
            // Group 2: no date — push to bottom, then by name
            return (2, .max, item.name.lowercased())
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
            
            if let days = item.daysUntilExpiry, days > 0 {
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
    }
    
    private func expiryLabel() -> (text: String, color: Color)? {
        guard let days = item.daysUntilExpiry else { return nil }
        if days < 0 { return ("Expired \(abs(days))d", .red) }
        if days == 0 { return ("Expires today", .orange) }
        if days <= 7 { return ("Expires in \(days)d", .orange) }
        return ("Expires in \(days)d", .secondary)
    }
}
