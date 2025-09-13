//
//  Utils.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 5/09/25.
//

import Foundation

public func daysUntil(_ date: Date?) -> Int? {
  guard let date else { return nil }
  return Calendar.current.dateComponents([.day], from: Date(), to: date).day
}

public func isExpired(_ date: Date?) -> Bool {
  (daysUntil(date) ?? 1) < 0
}

public func isExpiringSoon(_ date: Date?, within days: Int = 3) -> Bool {
  guard let d = daysUntil(date) else { return false }
  return d >= 0 && d <= days
}
