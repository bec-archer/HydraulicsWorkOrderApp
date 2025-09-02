//
//  ManagerReviewView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//


// ───── MANAGER REVIEW VIEW ─────
import SwiftUI

/// Manager can review a specific WO_Item: adjust parts/hours/notes, override completion if needed.
/// This scaffold shows the expected controls; real data binding will be wired later.
struct ManagerReviewView: View {
    @EnvironmentObject var appState: AppState

    // Stubs to simulate an editable WO_Item
    @State private var partsUsed: String = ""
    @State private var hoursWorked: String = ""
    @State private var notes: String = ""
    @State private var markCompleted: Bool = false

    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            Form {
                Section("Item Summary") {
                    // These would be read-only fields from the actual WO_Item
                    Text("WO 090125-004 • Cylinder • Item A")
                    Text("Status: In Progress")
                        .foregroundStyle(.secondary)
                    Text("Flag: PROBLEM CHILD")
                        .foregroundStyle(.red)
                }

                Section("Adjustments") {
                    TextField("Parts Used", text: $partsUsed)
                    TextField("Hours Worked", text: $hoursWorked)
                        .keyboardType(.decimalPad)
                    TextField("Manager Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Mark Work Order as Completed", isOn: $markCompleted)
                }

                Section {
                    Button("Save Review") {
                        // TODO: Write adjusted values to WorkOrdersDatabase and status history
                        // - Add WO_Status entry ("Manager Review")
                        // - If markCompleted: update WO status and affected item
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        // In a real flow, pop the view; here it’s a stub
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Manager Review")
        }
        // END
    }
}

// ───── PREVIEW ─────
#Preview {
    let s = AppState.previewLoggedIn(role: .manager)
    ManagerReviewView()
        .environmentObject(s)
}
// END