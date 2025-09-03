//
//  AddFoodItemView.swift
//  PantryPal
//
//  Created by Valery Patrizia Madiedo Gomez on 3/09/25.
//
import Foundation
import SwiftUI

struct AddFoodItemSheet: View {
    @Binding var name: String
    @Binding var qty: Int
    @Binding var notes: String
    @Binding var expiry: Date?          // nil = no expiry
    @Binding var isPresented: Bool
    
    let onConfirm: () -> Void
    
    // Separate, explicit binding so Toggle doesn’t confuse the compiler
    private var hasExpiryBinding: Binding<Bool> {
        Binding<Bool>(
            get: { expiry != nil },
            set: { isOn in
                if isOn {
                    if expiry == nil {
                        // choose a safe default (tomorrow) without inline Calendar gymnastics
                        expiry = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    }
                } else {
                    expiry = nil
                }
            }
        )
    }
    
    // DatePicker needs a non-optional Binding<Date>
    private var expiryBinding: Binding<Date> {
        Binding<Date>(
            get: { expiry ?? Date() },
            set: { expiry = $0 }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Item name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    Stepper("Quantity: \(qty)", value: $qty, in: 1...999)
                }
                
                Section("Expiration") {
                    Toggle("Has expiration date", isOn: hasExpiryBinding)
                    if expiry != nil {
                        DatePicker("Expires on", selection: expiryBinding, displayedComponents: .date)
                    }
                }
                
                Section("Notes") {
                    TextField("Optional", text: $notes)
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onConfirm()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

