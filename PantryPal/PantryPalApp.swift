//
//  PantryPalApp.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 1/09/25.
//

import SwiftUI
import ComposableArchitecture

@main
struct PantryApp: App {
  static let store = Store(
    initialState: PlacesFeature.State(),
    reducer: { PlacesFeature() }
  )

  var body: some Scene {
    WindowGroup {
      PlacesView(store: PantryApp.store)
    }
  }
}

