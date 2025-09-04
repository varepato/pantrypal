//
//  PantryPalApp.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 1/09/25.
//

// PantryApp.swift
import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct PantryApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
        // Register SwiftData models
            .modelContainer(for: [PlaceStore.self, FoodItemStore.self])
    }
}

// A tiny root so we can grab the SwiftData ModelContext and inject it into TCA
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        PlacesView(
            store: Store(initialState: PlacesFeature.State()) {
                PlacesFeature()
            } withDependencies: { deps in
                deps.db = .live(modelContext)        // 👈 inject SwiftData client
            }
        )
    }
}


