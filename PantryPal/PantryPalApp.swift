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
        
        let store = Store(initialState: PlacesFeature.State()) {
            PlacesFeature()
        } withDependencies: { deps in
            deps.db = .live(modelContext)
        }
        PlacesView(store: store)
            .task {
                // Seed snapshot on launch
                let db = DBClient.live(modelContext)
                if let places = try? await db.load() {
                    WidgetSnapshotWriter.saveFromPlaces(places)
                }
            }
            .onOpenURL { url in
                route(url, store: store)   // 👈 pass the store
            }
    }
    
    private func route(_ url: URL, store: StoreOf<PlacesFeature>) {
        guard url.scheme?.lowercased() == "pantrypal" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = url.host?.lowercased()
        
        let vs = ViewStore(store, observe: { _ in true })   // ✅ Bool is Equatable
        
        if host == "items" {
            vs.send(.openAllItems)
            return
        }
        if host == "expiration" {
            let filter = comps?.queryItems?.first(where: { $0.name == "filter" })?.value?.lowercased()
            switch filter {
            case "expired": vs.send(.bannerTapped(.expired))
            case "soon":    vs.send(.bannerTapped(.expiringSoon))
            default:        vs.send(.bannerTapped(.expiringSoon))
            }
        }
    }

}


/*
 TODO:
 - Remove item once it goes to zero
 - Edit place
 - Grocery list? > show a list of items to buy when low on items.
 - With ML :
    - Suggest common items
    - Suggest common places
    - Suggest recipes
 */
