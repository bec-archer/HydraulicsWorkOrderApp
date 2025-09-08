//
//  CustomerDetailView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI
import UIKit

// ─────────────────────────────────────────────────────────────
// 📄 CustomerDetailView.swift
// Displays customer details and their work order history
// ─────────────────────────────────────────────────────────────

struct CustomerDetailView: View {
    @State private var customer: Customer
    @StateObject private var workOrdersDatabase = WorkOrdersDatabase.shared

    init(customer: Customer) {
        self._customer = State(initialValue: customer)
    }
    @State private var customerWorkOrders: [WorkOrder] = []
    @State private var isLoading = false
    @State private var selectedWorkOrder: WorkOrder?
    @State private var showPhoneAlert = false
    @State private var showingPhoneActions = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Customer Info Section
                    CustomerInfoSection(
                        customer: customer,
                        showPhoneAlert: $showPhoneAlert,
                        showingPhoneActions: $showingPhoneActions,
                        onTagChange: { newTag in
                            // Customer tag functionality removed from model
                            // Persist the updated customer to Firebase
                            CustomerDatabase.shared.updateCustomer(customer) { result in
                                Task { @MainActor in
                                    switch result {
                                    case .success:
                                        print("✅ Customer tag updated successfully")
                                    case .failure(let error):
                                        print("❌ Failed to update customer tag: \(error)")
                                    }
                                }
                            }
                        }
                    )
                    
                    // Work Orders Section
                    WorkOrdersSection(
                        customerWorkOrders: customerWorkOrders,
                        isLoading: isLoading,
                        onWorkOrderSelected: { workOrder in
                            selectedWorkOrder = workOrder
                        }
                    )
                }
                .padding()
            }
            .navigationTitle(customer.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCustomerWorkOrders()
        }
        .sheet(item: $selectedWorkOrder) { workOrder in
            WorkOrderDetailView(workOrder: workOrder)
        }
        .alert("Phone Actions", isPresented: $showingPhoneActions) {
            Button("Call") {
                if !customer.phoneNumber.isEmpty {
                    call(customer.phoneNumber)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func loadCustomerWorkOrders() {
        isLoading = true
        workOrdersDatabase.fetchWorkOrdersByCustomer(customerId: customer.id.uuidString) { result in
            Task { @MainActor in
                isLoading = false
                switch result {
                case .success(let workOrders):
                    self.customerWorkOrders = workOrders
                case .failure(let error):
                    print("❌ Failed to load customer work orders: \(error)")
                }
            }
        }
    }
    
    private func call(_ phoneNumber: String) {
        let cleanNumber = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleanNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Customer Info Section
struct CustomerInfoSection: View {
    let customer: Customer
    @Binding var showPhoneAlert: Bool
    @Binding var showingPhoneActions: Bool
    var onTagChange: (String?) -> Void
    
    var body: some View {
        Text("Customer Info Placeholder")
    }
}

// MARK: - Work Orders Section
struct WorkOrdersSection: View {
    let customerWorkOrders: [WorkOrder]
    let isLoading: Bool
    let onWorkOrderSelected: (WorkOrder) -> Void
    
    var body: some View {
        Text("Work Orders Placeholder")
    }
}

// MARK: - Work Order Row View
struct WorkOrderRowView: View {
    let workOrder: WorkOrder
    let onTap: () -> Void
    
    var body: some View {
        Text("Work Order Row Placeholder")
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        Text("Info Row Placeholder")
    }
}

#Preview {
    CustomerDetailView(customer: Customer.sample)
        .environmentObject(AppState.shared)
}