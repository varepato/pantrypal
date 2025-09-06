//
//  ExpirationRowBuilder.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 5/09/25.
//

import Foundation
import ComposableArchitecture

func buildExpirationRows(
    kind: ExpirationKind,
    places: IdentifiedArrayOf<PlaceFeature.State>
) -> [ExpirationFeature.Row] {
    let now = Date()
    func daysUntil(_ date: Date?) -> Int? {
        guard let d = date else { return nil }
        return Calendar.current.dateComponents([.day], from: now, to: d).day
    }
    
    var rows: [ExpirationFeature.Row] = []
    
    for place in places {
        for item in place.items {
            let du = daysUntil(item.expirationDate)
            let include: Bool = {
                switch kind {
                case .expired: return (du ?? 1) < 0
                case .expiringSoon(let days):
                    guard let du else { return false }
                    return du >= 0 && du <= days
                }
            }()
            
            if include {
                rows.append(.init(
                    id: item.id,
                    placeID: place.id,
                    placeName: place.name,
                    placeIcon: place.iconName,
                    name: item.name,
                    quantity: item.quantity,
                    expirationDate: item.expirationDate,
                    daysUntilExpiry: du
                ))
            }
        }
    }
    
    switch kind {
    case .expired:
        rows.sort { ($0.daysUntilExpiry ?? 0) < ($1.daysUntilExpiry ?? 0) }   // more overdue first
    case .expiringSoon:
        rows.sort { ($0.daysUntilExpiry ?? .max) < ($1.daysUntilExpiry ?? .max) } // soonest first
    }
    return rows
}
