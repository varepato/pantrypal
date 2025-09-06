//
//  ExpirationFeature.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 5/09/25.
//

import SwiftUI
import ComposableArchitecture

enum ExpirationKind: Equatable {
    case expired
    case expiringSoon(days: Int)
}

@Reducer
struct ExpirationFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id = UUID()
        var kind: ExpirationKind
        var rows: [Row] = []
    }
    
    enum Action: Equatable {
        case rowTapped(Row)
        case closeTapped
        
        // Cleanup
        case cleanupAllTapped
        case delegate(Delegate)
        enum Delegate: Equatable {
            case cleanupExpired
        }
    }
    
    struct Row: Equatable, Identifiable {
        var id: UUID
        var placeID: UUID
        var placeName: String
        var placeIcon: String
        var name: String
        var quantity: Int
        var expirationDate: Date?
        var daysUntilExpiry: Int?
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .cleanupAllTapped:
                return .send(.delegate(.cleanupExpired))
            case .rowTapped, .closeTapped, .delegate:
                return .none
            }
        }
    }
}
