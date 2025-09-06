//
//  PlacesView+Components.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 5/09/25.
//

import SwiftUI

struct StatusBanner: View {
    enum Kind { case expired, expiringSoon }
    
    let kind: Kind
    let count: Int
    let onTap: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(kind == .expired ? Color.red : Color.orange) 
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        )
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
    
    private var title: String {
        switch kind {
        case .expired: return "Expired items"
        case .expiringSoon: return "Expiring soon"
        }
    }
    
    private var message: String {
        switch kind {
        case .expired:
            return count == 1
            ? "You have 1 expired item. Yuck! Clean that up!"
            : "You have \(count) expired items. Yuck! Clean that up!"
        case .expiringSoon:
            return count == 1
            ? "1 item is expiring soon. Go eat it!"
            : "\(count) items are expiring soon. You better go eat them!"
        }
    }
}

struct PlacesGrid: View {
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
                    let hasExpiringSoon = place.items.elements.contains { isExpiringSoon($0.expirationDate, within: 3) }
                    PlaceCard(
                        place: place,
                        hasExpiringSoon: hasExpiringSoon,
                        hasExpired: hasExpired,
                        onTap: { onTap(place) },
                        onDelete: { onDelete(place.id) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }
}

struct PlaceCard: View {
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

struct AddPlaceSheet: View {
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

struct IconPicker: View {
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


