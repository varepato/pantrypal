//
//  ContentView.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 1/09/25.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct CounterFeature {
  @ObservableState struct State: Equatable { var count = 0 }
  enum Action { case increment, decrement }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .increment: state.count += 1; return .none
      case .decrement: state.count -= 1; return .none
      }
    }
  }
}

struct ContentView: View {
  let store: StoreOf<CounterFeature>
  var body: some View {
    WithPerceptionTracking {
      HStack(spacing: 24) {
        Button("−") { store.send(.decrement) }
        Text("\(store.count)").monospaced().font(.title)
        Button("+") { store.send(.increment) }
      }.padding()
    }
  }
}
