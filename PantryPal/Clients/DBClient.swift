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
            replaceAll: { _ in }
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
                try await MainActor.run {
                    let existing = try context.fetch(FetchDescriptor<PlaceStore>(
                        sortBy: [SortDescriptor(\.name, order: .forward)]
                    ))
                    existing.forEach { context.delete($0) }
                    for p in places {
                        let place = PlaceStore(
                            id: p.id,
                            name: p.name,
                            iconName: p.iconName,
                            colorHex: p.colorHex
                        )
                        for it in p.items {
                            place.items.append(
                                FoodItemStore(
                                    id: it.id,
                                    name: it.name,
                                    quantity: it.quantity,
                                    notes: it.notes,
                                    expirationDate: it.expirationDate,
                                    place: place
                                )
                            )
                        }
                        context.insert(place)
                    }
                    try context.save()
                }
            }
        )
    }
}
