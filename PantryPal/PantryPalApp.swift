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
    init() {
      BackgroundRefresh.register()
    }
    var body: some Scene {
        WindowGroup { RootView() }
        // Register SwiftData models
            .modelContainer(for: [PlaceStore.self, FoodItemStore.self, ShoppingListItemStore.self])
    }
}

// A tiny root so we can grab the SwiftData ModelContext and inject it into TCA
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var store: StoreOf<PlacesFeature>?
    
    var body: some View {
      Group {
        if let store {
          PlacesView(store: store)
            .task {
              // DEBUG: schedule BG task
              #if DEBUG
              BackgroundRefresh.schedule()
              #endif

              // Seed widget snapshot (read-only)
              let db = DBClient.live(modelContext)
              if let places = try? await db.load() {
                WidgetSnapshotWriter.saveFromPlaces(places)
              }

              // ✅ Load DB into TCA state BEFORE any writes occur
              ViewStore(store, observe: { _ in true }).send(.loadRequested)
            }
            .onOpenURL { url in route(url, store: store) }
            .onChange(of: scenePhase) { _, newPhase in
              if newPhase == .background { BackgroundRefresh.schedule() }
            }
        } else {
          ProgressView().task {
            store = Store(initialState: PlacesFeature.State()) {
              PlacesFeature()
            } withDependencies: { $0.db = .live(modelContext) }
          }
        }
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


