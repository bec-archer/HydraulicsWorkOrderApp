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
    let customer: Customer
    @StateObject private var workOrdersDatabase = WorkOrdersDatabase.shared
    @State private var customerWorkOrders: [WorkOrder] = []
    @State private var isLoading = false
    @State private var selectedWorkOrder: WorkOrder?
    @State private var showPhoneAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Customer Info Section
                    CustomerInfoSection(customer: customer, showPhoneAlert: $showPhoneAlert)
                    
                    // Work Orders Section
                    WorkOrdersSection(
                        workOrders: customerWorkOrders,
                        isLoading: isLoading,
                        onWorkOrderTap: { workOrder in
                            selectedWorkOrder = workOrder
                        }
                    )
                }
                .padding()
            }
            .navigationTitle("Customer Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedWorkOrder) { workOrder in
                NavigationStack {
                    WorkOrderDetailView(workOrder: workOrder)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    selectedWorkOrder = nil
                                }
                            }
                        }
                }
            }
            .alert("Phone Number Copied", isPresented: $showPhoneAlert) {
                Button("OK") { }
            } message: {
                Text("The phone number has been copied to your clipboard since phone calls aren't available in the simulator.")
            }
            .onAppear {
                loadCustomerWorkOrders()
            }
        }
    }
    
    private func loadCustomerWorkOrders() {
        isLoading = true
        workOrdersDatabase.fetchWorkOrdersByCustomer(customerId: customer.id.uuidString) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let workOrders):
                    self.customerWorkOrders = workOrders
                case .failure(let error):
                    print("❌ Failed to load work orders for customer: \(error)")
                    self.customerWorkOrders = []
                }
            }
        }
    }
}

// MARK: - Customer Info Section
struct CustomerInfoSection: View {
    let customer: Customer
    @Binding var showPhoneAlert: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Customer Information")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Name", value: customer.name)
                // Tappable phone number
                HStack {
                    Text("Phone")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Text(customer.phone)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#FFC500"))
                        .underline()
                        .onLongPressGesture {
                            let cleanedPhone = customer.phone.replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: "-", with: "")
                                .replacingOccurrences(of: "(", with: "")
                                .replacingOccurrences(of: ")", with: "")
                            
                            if let url = URL(string: "tel:\(cleanedPhone)") {
                                UIApplication.shared.open(url) { success in
                                    if !success {
                                        // Fallback: copy to clipboard and show feedback
                                        UIPasteboard.general.string = customer.phone
                                        DispatchQueue.main.async {
                                            showPhoneAlert = true
                                        }
                                    }
                                }
                            }
                        }
                    
                    Spacer()
                }
                
                if let company = customer.company, !company.isEmpty {
                    InfoRow(label: "Company", value: company)
                }
                
                if let email = customer.email, !email.isEmpty {
                    InfoRow(label: "Email", value: email)
                }
                
                InfoRow(label: "Tax Status", value: customer.taxExempt ? "Tax Exempt" : "Taxable")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Work Orders Section
struct WorkOrdersSection: View {
    let workOrders: [WorkOrder]
    let isLoading: Bool
    let onWorkOrderTap: (WorkOrder) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Work Orders")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(workOrders.count)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading work orders...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if workOrders.isEmpty {
                Text("No work orders found for this customer")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(workOrders, id: \.id) { workOrder in
                        WorkOrderRowView(workOrder: workOrder)
                            .onTapGesture {
                                onWorkOrderTap(workOrder)
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Work Order Row View
struct WorkOrderRowView: View {
    let workOrder: WorkOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workOrder.WO_Number)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(workOrder.WO_Type)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: workOrder.status)
                    
                    Text(workOrder.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let estimatedCost = workOrder.estimatedCost, !estimatedCost.isEmpty {
                HStack {
                    Text("Est. Cost:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(estimatedCost)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            if workOrder.flagged {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.orange)
                    Text("Flagged for follow-up")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}



// MARK: - Preview
#Preview {
    CustomerDetailView(customer: Customer.sample)
        .environmentObject(AppState.shared)
}
