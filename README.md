# PantryPal

Offline-first pantry & shopping assistant built with SwiftUI, TCA, and SwiftData.

This README focuses on **active workstreams** only. Future ideas are tracked elsewhere.

---

## 1. Core Architecture & State Management

**Status:** In progress / stabilizing

**Goals**

* Maintain a clean, scalable TCA architecture
* Keep features isolated but composable
* Ensure predictable navigation and side effects

**Current Focus**

* Root `PlacesFeature` managing navigation, banners, and add-place flow
* Child `PlaceFeature` for per-place item management
* `ExpirationFeature` as a flattened, cross-place view of expiring items
* Navigation via `NavigationStackStore` with typed paths

**Open Work**

* Continue reducing feature coupling
* Audit delegate actions and parent-child responsibilities

---

## 2. Persistence Layer (SwiftData + DBClient)

**Status:** Active

**Goals**

* Reliable offline-first persistence
* Clear boundary between feature state and storage

**Current Focus**

* SwiftData models (`PlaceStore`, `FoodItemStore`)
* `DBClient` abstraction for loading and replacing snapshots
* Dependency injection into features

**Open Work**

* Move from full snapshot replacement to incremental CRUD
* Add lightweight migrations support

---

## 3. Places & Items Management

**Status:** Active

**Goals**

* Simple mental model: places contain items
* Fast add/edit/delete flows

**Current Focus**

* Grid-based `PlacesView` with visual status indicators
* Per-place item lists with quantities
* FAB-driven add flows

**Open Work**

* Editing existing places (name, icon, color)
* Sorting items by expiration
* Search within a place

---

## 4. Expiration & Alerts Logic

**Status:** Active

**Goals**

* Make expiration visible without being annoying
* Centralize all expiration logic

**Current Focus**

* `daysUntil`, `isExpired`, `isExpiringSoon`
* Configurable expiring-soon window (default: 3 days)
* Flattened expiration rows across places
* Visual indicators (expired vs expiring soon)

**Open Work**

* User-configurable expiration window
* Bulk cleanup actions
* Optional local notifications (still offline-first)

---

## 5. Shopping List Feature

**Status:** Active / expanding

**Goals**

* Bridge planning (shopping) with inventory (pantry)
* Reduce duplicate data entry

**Current Focus**

* Shopping list items with loading and error states
* Empty-state UX
* Add-item sheet

**Open Work**

* Assign a destination place when adding a shopping item
* Convert shopping items into pantry items
* Cross-feature coordination with `PlacesFeature`

---

## 6. Home Screen Widget (Expired Items)

**Status:** Active / partially shipped

**Goals**

* Surface critical expiration info without opening the app
* Keep widget glanceable, calm, and low-maintenance

**Current Focus**

* iOS home screen widget showing expired items
* Uses shared expiration logic with main app
* Clearly distinguishes expired items from expiring-soon ones

**Open Work**

* Multiple widget sizes (small / medium)
* Better empty-state messaging when nothing is expired
* Performance and refresh tuning

---

## 7. UI / UX Polish

**Status:** Continuous

**Goals**

* Calm, neutral UI
* Clear hierarchy and affordances

**Current Focus**

* Two-column grid for places
* Neutral floating action buttons
* Dismissible banners for alerts
* Per-place color tinting

**Open Work**

* Color editing after place creation
* Accessibility review (contrast, dynamic type)
* Motion reduction where applicable

---

## 7. Offline-First Guarantees

**Status:** Active principle

**Goals**

* App must function fully without network access
* No hard dependency on remote services

**Current Focus**

* Local-only persistence
* No cloud sync assumptions

**Open Work**

* Stress test large local datasets
* Performance profiling on older devices

---

## Summary

PantryPal is currently focused on **solidifying its core architecture**, **strengthening offline persistence**, and **tightening the loop between shopping and inventory**. Feature depth is increasing deliberately, with UX polish happening alongside structural work rather than at the end.
