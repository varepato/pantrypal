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
                        },
                        onSetExpiry: { newDate in
                            store.send(.setItemExpiry(id: item.id, date: newDate))
                        }
                    )
                    .background(
                        Color.clear.anchorPreference(
                            key: RowAnchorKey.self,
                            value: .bounds,
                            transform: { [item.id: $0] }
                        )
                    )
                }
                .onDelete { store.send(.deleteItems($0)) }
            }
        }
        ZStack {
            // Your list + other UI
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
    let onSetExpiry: (Date?) -> Void

    @State private var tempDate = Date()
    private let pickerTapWidth: CGFloat = 180   // <= keep this narrower than the row

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name).font(.headline)
                    Text("• \(item.quantity)").font(.subheadline).foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    // Your label
                    let labelView = Group {
                        if let label = expiryLabel() {
                            Text("\(label.text)").font(.caption).foregroundStyle(label.color)
                        } else {
                            Text("No expiration date").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    // Overlay compact DatePicker on the label
                    labelView
                        // ⬇️ Long-press here to show Clear
                        .contextMenu {
                            if item.expirationDate != nil {
                                Button("Clear date", role: .destructive) {
                                    onSetExpiry(nil)
                                    // (optional) reset tempDate for next open:
                                    // tempDate = Date()
                                }
                            } else {
                                // Optional helper when no date yet:
                                Button("Set to today") {
                                    let d = Date()
                                    tempDate = d
                                    onSetExpiry(d)
                                }
                            }
                        }
                        .overlay(alignment: .leading) {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { tempDate },
                                    set: { newValue in
                                        tempDate = newValue
                                        onSetExpiry(newValue)  // commit on pick
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(width: pickerTapWidth, height: 24, alignment: .leading)
                            .contentShape(Rectangle())
                            .opacity(0.02) // invisible but tappable
                            .allowsHitTesting(true)
                        }
                        .onAppear { tempDate = item.expirationDate ?? Date() }
                }

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Stepper(
                value: Binding(get: { item.quantity }, set: { onQtyChange($0) }),
                in: 0...999
            ) { EmptyView() }
            .labelsHidden()
        }
    }

    private func expiryLabel() -> (text: String, color: Color)? {
        guard let d = item.daysUntilExpiry else { return nil }
        if d < 0 { return ("Expired \(abs(d))d ago", .red) }
        if d == 0 { return ("Expires today", .orange) }
        if d <= 7 { return ("Expires in \(d)d", .orange) }
        return ("Expires in \(d)d", .secondary)
    }
}



struct RowAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [UUID: Anchor<CGRect>],
                       nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct FloatingDateCard: View {
    @Binding var date: Date
    let onCommit: (Date?) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.graphical)
            
            HStack {
                Button("Clear", role: .destructive) {
                    onCommit(nil); onDismiss()
                }
                Spacer()
                Button("Done") {
                    onCommit(date); onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 6)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.quaternaryLabel), lineWidth: 1)
        )
        .shadow(radius: 16, y: 8)
    }
}

