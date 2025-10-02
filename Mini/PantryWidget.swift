//
//  PantryWidget.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 11/09/25.
//

import SwiftUI
import WidgetKit

// MARK: - Deep links your app will handle
enum Deeplink {
    static let all     = URL(string: "pantrypal://items")!
    static let soon    = URL(string: "pantrypal://expiration?filter=soon")!
    static let expired = URL(string: "pantrypal://expiration?filter=expired")!
}

// MARK: - Entry
struct PantryEntry: TimelineEntry {
    let date: Date
    let total: Int
    let soon: Int
    let expired: Int
}

// MARK: - Provider
struct PantryProvider: TimelineProvider {
    func placeholder(in context: Context) -> PantryEntry {
        PantryEntry(date: .now, total: 24, soon: 3, expired: 1)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PantryEntry) -> Void) {
        completion(load())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PantryEntry>) -> Void) {
      let entry = load()

      // refresh around 3:05 AM local time
      let calendar = Calendar.current
      let now = Date()
      let next = calendar.nextDate(
        after: now,
        matching: DateComponents(hour: 3, minute: 5, second: 0),
        matchingPolicy: .nextTime
      ) ?? now.addingTimeInterval(6 * 3600)

      completion(Timeline(entries: [entry], policy: .after(next)))
    }
    
    private func load() -> PantryEntry {
        if let s = WidgetSnapshotStore.load() {
            return PantryEntry(date: s.updatedAt, total: s.totalItems, soon: s.expiringSoon, expired: s.expired)
        } else {
            return PantryEntry(date: .now, total: 0, soon: 0, expired: 0)
        }
    }
}

// MARK: - View
struct PantryWidgetView: View {
    @Environment(\.widgetFamily) var family
    let e: PantryProvider.Entry
    
    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }
    
    // Small: single smart tap
    private var smallView: some View {
        let tapURL = e.expired > 0 ? Deeplink.expired : (e.soon > 0 ? Deeplink.soon : Deeplink.all)
        return ZStack {
            // Whole widget tap
            Link(destination: tapURL) {
                content(showSeparateLinks: false)
            }
        }
        .containerBackground(.thinMaterial, for: .widget)
        .padding(12)
    }
    
    // Medium: separate taps for badges + header tap to All
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(e.total)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("items in pantry").font(.system(size: 24, weight: .bold, design: .rounded))
            }
            
            if e.soon > 0 || e.expired > 0 {
                VStack {
                    if e.soon > 0 {
                        Link(destination: Deeplink.soon) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "clock.badge.exclamationmark")
                                  .symbolRenderingMode(.palette)        // triangle + exclamation
                                  .foregroundStyle(.orange)     // primary, secondary
                                  .font(.subheadline)
                                  .frame(width: 10, height: 10)
                                  .padding(.top, 5)
                                
                                Text("\(e.soon) expiring soon")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        .accessibilityLabel("\(e.soon) items expiring soon. Open expiring list.")
                    }
                    if e.expired > 0 {
                        // Duplicate link to expired for medium row, ok to keep for symmetry (or remove)
                        Link(destination: Deeplink.expired) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "xmark.octagon.fill")
                                  .symbolRenderingMode(.palette)        // octagon + X
                                  .foregroundStyle(.white, .red)
                                  .font(.subheadline)
                                  .frame(width: 10, height: 10)
                                  .padding(.top, 5)
                                
                                Text("\(e.expired) expired")
                                    .font(.subheadline)
                                
                                Spacer()
                            }
                        }
                        .accessibilityLabel("\(e.expired) items expired. Open expired list.")
                    }
                    Spacer()
                }
            } else {
                Link(destination: Deeplink.all) {
                    Text("All good — view all items")
                        .font(.footnote)
                }
                .accessibilityLabel("No warnings. Open all items.")
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.thinMaterial, for: .widget)
        .padding(12)
    }
    
    @ViewBuilder
    private func content(showSeparateLinks: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(e.total)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("items").font(.system(size: 20, weight: .bold, design: .rounded))
            }
            if e.soon > 0 || e.expired > 0 {
                VStack {
                    if e.soon > 0 {
                        Link(destination: Deeplink.soon) {
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: "clock.badge.exclamationmark")
                                  .symbolRenderingMode(.palette)        // triangle + exclamation
                                  .foregroundStyle(.orange)     // primary, secondary
                                  .font(.subheadline)
                                  .frame(width: 10, height: 10)
                                  .padding(.top, 5)
                                
                                Text("\(e.soon) soon")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        .accessibilityLabel("\(e.soon) items expiring soon. Open expiring list.")
                    }
                    if e.expired > 0 {
                        // Duplicate link to expired for medium row, ok to keep for symmetry (or remove)
                        Link(destination: Deeplink.expired) {
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: "xmark.octagon.fill")
                                  .symbolRenderingMode(.palette)        // octagon + X
                                  .foregroundStyle(.white, .red)
                                  .font(.subheadline)
                                  .frame(width: 10, height: 10)
                                  .padding(.top, 5)
                                
                                Text("\(e.expired) exp")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                            }
                        }
                        .accessibilityLabel("\(e.expired) items expired. Open expired list.")
                    }
                    Spacer()
                }
            } else {
                Text("All good — view all items")
                    .font(.footnote)
            }
            Spacer(minLength: 0)
        }
    }
    
    private func badge(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

// MARK: - Entry point
@main
struct PantryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Mini", provider: PantryProvider()) { entry in
            PantryWidgetView(e: entry)
        }
        .configurationDisplayName("Pantry Overview")
        .description("See total items and jump to warnings.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

