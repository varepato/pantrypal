//
//  DBClient.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 4/09/25.
//

// DBClient.swift
import Foundation
import SwiftData
import ComposableArchitecture

struct DBClient {
    var load: @Sendable () async throws -> [PlaceFeature.State]
    var replaceAll: @Sendable ([PlaceFeature.State]) async throws -> Void
    var loadShoppingList: @Sendable () async throws -> [ShoppingListItemDTO]
    var mergeOrCreateShoppingItem: @Sendable (_ name: String, _ qty: Int, _ source: ShoppingListItemDTO.Source, _ linked: UUID?, _ placeID: UUID?) async throws -> ShoppingListItemDTO
    var updateShoppingItem: @Sendable (_ item: ShoppingListItemDTO) async throws -> Void
    var deleteShoppingItems: @Sendable (_ ids: [UUID]) async throws -> Void
    var markPurchased: @Sendable (_ ids: [UUID], _ purchased: Bool) async throws -> Void
}

extension DependencyValues {
    var db: DBClient {
        get { self[DBClient.self] }
        set { self[DBClient.self] = newValue }
    }
}

extension DBClient: DependencyKey {
    // Default live (no-op). We'll override in RootView with .live(modelContext)
    static var liveValue: Self {
        Self(
            load: { [] },
            replaceAll: { _ in },
            loadShoppingList: { [] },
            mergeOrCreateShoppingItem: { name, qty, source, linked, placeID  in
                ShoppingListItemDTO(
                    id: UUID(), name: name, desiredQuantity: max(1, qty),
                    notes: nil,
                    source: source,
                    status: .toBuy,
                    linkedFoodItemID: linked,
                    createdAt: .now,
                    updatedAt: .now,
                    lastPlaceID: placeID
                )
            },
            updateShoppingItem: { _ in },
            deleteShoppingItems: { _ in },
            markPurchased: { _, _ in } // NEW

        )
    }
    
    // Reasonable defaults for previews/tests
    static var previewValue: Self { liveValue }
    static var testValue: Self { liveValue }
}

// Your real SwiftData-backed implementation
extension DBClient {
    static func live(_ context: ModelContext) -> Self {
        .init(
            load: {
                try await MainActor.run {
                    let places = try context.fetch(FetchDescriptor<PlaceStore>(
                        sortBy: [SortDescriptor(\.name, order: .forward)]
                    ))
                    return places.map { ps in
                        PlaceFeature.State(
                            id: ps.id,
                            name: ps.name,
                            iconName: ps.iconName,
                            colorHex: ps.colorHex,
                            items: .init(uniqueElements:
                                            ps.items.map {
                                                FoodItem(
                                                    id: $0.id,
                                                    name: $0.name,
                                                    quantity: $0.quantity,
                                                    notes: $0.notes,
                                                    expirationDate: $0.expirationDate
                                                )
                                            }
                                        )
                        )
                    }
                }
            },
            replaceAll: { places in
                var didPersist = false
                try await MainActor.run {
                    let existing = try context.fetch(FetchDescriptor<PlaceStore>())
                    if !existing.isEmpty && places.isEmpty {
                        print("⚠️ replaceAll skipped: empty snapshot would wipe \(existing.count) place(s)")
                        return
                    }
                    print("ℹ️ replaceAll applying snapshot: \(places.count) place(s)")
                    existing.forEach { context.delete($0) }
                    for p in places {
                        let place = PlaceStore(id: p.id, name: p.name, iconName: p.iconName, colorHex: p.colorHex)
                        for it in p.items {
                            place.items.append(FoodItemStore(id: it.id, name: it.name, quantity: it.quantity,
                                                             notes: it.notes, expirationDate: it.expirationDate, place: place))
                        }
                        context.insert(place)
                    }
                    try context.save()
                    didPersist = true
                }
                if didPersist { WidgetSnapshotWriter.saveFromPlaces(places) }
            },
            loadShoppingList: {
                try await MainActor.run {
                    let items = try context.fetch(FetchDescriptor<ShoppingListItemStore>(
                        sortBy: [
                            // Show newest first; adjust to taste
                            SortDescriptor(\.createdAt, order: .reverse),
                            SortDescriptor(\.name, order: .forward)
                        ]
                    ))
                    return items.map(ShoppingListItemDTO.init(model:))
                }
            },
            mergeOrCreateShoppingItem: { name, qty, source, linked, placeID in
                try await MainActor.run {
                    // 1) Normalize the incoming name exactly like the model does
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalizedKey = ShoppingListItemStore.normalizeKey(trimmed)
                    let now = Date()
                    
                    // 2) Try to find an existing row by normalizedKey
                    var fetch = FetchDescriptor<ShoppingListItemStore>()
                    fetch.predicate = #Predicate { $0.normalizedKey == normalizedKey }
                    fetch.fetchLimit = 1
                    
                    if var existing = try context.fetch(fetch).first {
                        // 3) Update existing: bump quantity, timestamps, source/linked if helpful
                        existing.desiredQuantity = max(1, existing.desiredQuantity + max(1, qty))
                        // if you want to keep the earliest createdAt, do nothing; else uncomment next line
                        // existing.createdAt = min(existing.createdAt, now)
                        existing.updatedAt = now
                        // Optionally preserve a linkage if previously nil
                        if existing.linkedFoodItemID == nil { existing.linkedFoodItemID = linked }
                        // (Optional) last source wins — or keep original; up to you
                        // existing.source = (source == .manual) ? existing.source : mapSource(source)
                        if existing.lastPlaceID == nil, let placeID { existing.lastPlaceID = placeID }
                        if existing.linkedFoodItemID == nil { existing.linkedFoodItemID = linked }
                        try context.save()
                        return ShoppingListItemDTO(model: existing)
                    } else {
                        // 4) Create new row
                        let model = ShoppingListItemStore(
                            name: trimmed,
                            desiredQuantity: max(1, qty),
                            notes: nil,
                            source: {
                                switch source {
                                case .expiredCleanup: .expiredCleanup
                                case .depleted:       .depleted
                                case .manual:         .manual
                                }
                            }(),
                            linkedFoodItemID: linked,
                            status: .toBuy,
                            createdAt: now,
                            updatedAt: now,
                            lastPlaceID: placeID
                        )
                        
                        context.insert(model)
                        try context.save()
                        return ShoppingListItemDTO(model: model)
                    }
                }
            },
            updateShoppingItem: { item in
              try await MainActor.run {
                // 1) Capture the id outside the predicate
                let targetID = item.id

                // 2) Build a typed fetch descriptor
                var fetch = FetchDescriptor<ShoppingListItemStore>()
                fetch.predicate = #Predicate<ShoppingListItemStore> { $0.id == targetID }
                fetch.fetchLimit = 1

                if let model = try context.fetch(fetch).first {
                  _ = model.updating(from: .init(
                    id: item.id,
                    name: item.name,
                    desiredQuantity: max(1, item.desiredQuantity),
                    notes: item.notes,
                    source: item.source,
                    status: item.status,
                    linkedFoodItemID: item.linkedFoodItemID,
                    createdAt: model.createdAt,
                    updatedAt: Date()
                  ))
                  try context.save()
                }
              }
            },
            deleteShoppingItems: { ids in
              try await MainActor.run {
                guard !ids.isEmpty else { return }
                var fetch = FetchDescriptor<ShoppingListItemStore>()
                fetch.predicate = #Predicate { ids.contains($0.id) }

                let matches = try context.fetch(fetch)
                matches.forEach { context.delete($0) }
                try context.save()
              }
            },
            markPurchased: { ids, purchased in
              try await MainActor.run {
                guard !ids.isEmpty else { return }
                let idSet = Set(ids) // capture as Set to keep #Predicate happy

                var fetch = FetchDescriptor<ShoppingListItemStore>()
                fetch.predicate = #Predicate<ShoppingListItemStore> { idSet.contains($0.id) }

                let matches = try context.fetch(fetch)
                let now = Date()
                for m in matches {
                  m.status = purchased ? .purchased : .toBuy
                  m.updatedAt = now
                }
                if !matches.isEmpty {
                  try context.save()
                }
              }
            },


        )
    }
}
