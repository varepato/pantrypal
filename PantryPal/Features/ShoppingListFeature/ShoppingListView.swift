//
//  ShoppingListView.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 2/10/25.
//

import SwiftUI
import ComposableArchitecture

struct ShoppingListView: View {
    let store: StoreOf<ShoppingListFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { vs in
            List {
                if let error = vs.error {
                    Text("Error: \(error)").foregroundStyle(.red)
                }
                
                if vs.items.isEmpty, !vs.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "cart")
                            .font(.system(size: 32, weight: .regular))
                            .padding(.top, 16)
                        Text("No items yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(vs.items, id: \.id) { item in
                      HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.name).font(.headline)
                                Text("• \(item.desiredQuantity)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                          Text(item.source == .manual ? "Manual" :
                               item.source == .depleted ? "Depleted" : "Expired")
                          .font(.caption).foregroundStyle(.secondary)
                        }
                          Spacer()
                          Stepper(
                            value: .init(
                                get: { item.desiredQuantity },
                                set: { store.send(.setQuantity(id: item.id, qty: $0)) }
                            ),
                            in: 1...999
                          ) {
                          Text("x\(item.desiredQuantity)")
                            .monospacedDigit()
                        }
                        .labelsHidden() // we render the count ourselves
                      }
                    }
                    .onDelete { offsets in store.send(.delete(offsets)) } 
                }
            }
            .overlay {
                if vs.isLoading {
                    ProgressView().controlSize(.large)
                }
            }
            .navigationTitle("Shopping List")
            .task { vs.send(.onAppear) }
            // NEW: plus button
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.send(.addButtonTapped) } label: { Image(systemName: "plus") }
                }
            }
            
            .sheet(
              store: store.scope(state: \.$addSheet, action: ShoppingListFeature.Action.addSheet)
            ) { AddSheetView(store: $0) }

        }
    }
}

struct AddSheetView: View {
    let store: StoreOf<ShoppingListFeature.AddSheet>
    var body: some View {
        WithViewStore(store, observe: { $0 }) { vs in
            NavigationStack {
                Form {
                    TextField("Item name", text: vs.binding(
                        get: \.name, send: ShoppingListFeature.AddSheet.Action.setName))
                    Stepper(value: vs.binding(
                        get: \.qty, send: ShoppingListFeature.AddSheet.Action.setQty), in: 1...999) {
                            Text("Quantity: \(vs.qty)")
                        }
                }
                .navigationTitle("Add to Shopping List")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { vs.send(.cancel) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let trimmed = vs.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { store.send(.confirm(trimmed, vs.qty)) }
                        }.disabled(vs.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}
