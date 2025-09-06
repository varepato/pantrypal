//
//  ExpirationView.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 5/09/25.
//

import SwiftUI
import ComposableArchitecture

struct ExpirationView: View {
    let store: StoreOf<ExpirationFeature>
    
    private var title: String {
        switch store.kind {
        case .expired: return "Expired items"
        case .expiringSoon: return "Expiring soon"
        }
    }
    
    var body: some View {
        List {
            ForEach(store.rows) { row in
                HStack(spacing: 12) {
                    Image(systemName: row.placeIcon)
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(.headline)
                        
                        Text("\(row.quantity) • \(row.placeName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let d = row.daysUntilExpiry {
                            let result = status(for: d)
                            
                            Text(result.text)
                                .font(.caption)
                                .foregroundColor(result.color)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { store.send(.rowTapped(row)) }
            }
        }
        .navigationTitle(title)
        .toolbar {
            // Clean up button only for expired list
            ToolbarItem(placement: .topBarTrailing) {
                if case .expired = store.kind {
                    Button("Clean up") { store.send(.cleanupAllTapped) }
                }
            }
        }
    }
    
    private func status(for daysUntil: Int) -> (text: String, color: Color) {
      if daysUntil < 0 {
        return ("Expired \(abs(daysUntil))d ago", .red)
      } else if daysUntil == 0 {
        return ("Expires today", .orange)
      } else {
        return ("Expires in \(daysUntil)d", .orange)
      }
    }
}
