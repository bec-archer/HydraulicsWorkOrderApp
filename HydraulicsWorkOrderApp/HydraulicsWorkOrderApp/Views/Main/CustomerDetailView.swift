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
                        onTagChange: { updatedCustomer in
                            // Update the local customer state
                            customer = updatedCustomer
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
    @State private var customer: Customer
    @Binding var showPhoneAlert: Bool
    @Binding var showingPhoneActions: Bool
    var onTagChange: (Customer) -> Void
    
    @State private var showingEditCustomer = false
    @State private var isEditing = false
    
    init(customer: Customer, showPhoneAlert: Binding<Bool>, showingPhoneActions: Binding<Bool>, onTagChange: @escaping (Customer) -> Void) {
        self._customer = State(initialValue: customer)
        self._showPhoneAlert = showPhoneAlert
        self._showingPhoneActions = showingPhoneActions
        self.onTagChange = onTagChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ───── Header with Edit Button ─────
            HStack {
                Text("Customer Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Edit") {
                    showingEditCustomer = true
                }
                .buttonStyle(.bordered)
            }
            
            // ───── Customer Details Card ─────
            VStack(alignment: .leading, spacing: 12) {
                // Name with emoji tag
                HStack(spacing: 8) {
                    if let emoji = customer.emojiTag, !emoji.isEmpty {
                        Text(emoji)
                            .font(.title2)
                    }
                    Text(customer.name)
                        .font(.title3)
                        .fontWeight(.medium)
                }
                
                Divider()
                
                // Phone number (tappable)
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Button(customer.formattedPhone) {
                        showingPhoneActions = true
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                }
                
                // Company (if available)
                if let company = customer.company, !company.isEmpty {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        Text(company)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // Email (if available)
                if let email = customer.email, !email.isEmpty {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        Text(email)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // Tax exempt status
                if customer.taxExempt {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        
                        Text("Tax Exempt")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingEditCustomer) {
            EditCustomerView(customer: customer) { updatedCustomer in
                customer = updatedCustomer
                onTagChange(updatedCustomer)
            }
        }
    }
}

// MARK: - Work Orders Section
struct WorkOrdersSection: View {
    let customerWorkOrders: [WorkOrder]
    let isLoading: Bool
    let onWorkOrderSelected: (WorkOrder) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ───── Header ─────
            HStack {
                Text("Work Orders")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(customerWorkOrders.count)")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // ───── Content ─────
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading work orders...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if customerWorkOrders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No Work Orders")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("This customer hasn't had any work orders yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(customerWorkOrders) { workOrder in
                        WorkOrderRowView(workOrder: workOrder) {
                            onWorkOrderSelected(workOrder)
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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // ───── Work Order Number ─────
                VStack(alignment: .leading, spacing: 4) {
                    Text(workOrder.workOrderNumber)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(workOrder.status)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // ───── Date and Status ─────
                VStack(alignment: .trailing, spacing: 4) {
                    Text(workOrder.timestamp, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(workOrder.status)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                }
                
                // ───── Arrow ─────
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // ───── Status Color Helper ─────
    private var statusColor: Color {
        switch workOrder.status.lowercased() {
        case "checked in":
            return .blue
        case "in progress", "working":
            return .orange
        case "completed", "done":
            return .green
        case "closed":
            return .gray
        default:
            return .secondary
        }
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
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Edit Customer View
struct EditCustomerView: View {
    @State private var customer: Customer
    let onSave: (Customer) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedEmoji: String? = nil
    @FocusState private var focusedField: Field?
    
    enum Field { case name, phone, company, email }
    
    init(customer: Customer, onSave: @escaping (Customer) -> Void) {
        self._customer = State(initialValue: customer)
        self._selectedEmoji = State(initialValue: customer.emojiTag)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // ───── Basic Info ─────
                Section(header: Text("Basic Information")) {
                    TextField("Full Name", text: $customer.name)
                        .focused($focusedField, equals: .name)
                    
                    TextField("Phone Number", text: $customer.phoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)
                }
                
                // ───── Emoji Tag ─────
                Section(header: Text("Emoji Tag"), footer: Text("Select an emoji to help identify this customer")) {
                    EmojiSelectionView(selectedEmoji: $selectedEmoji)
                }
                
                // ───── Optional Info ─────
                Section(header: Text("Optional Information")) {
                    TextField("Company", text: Binding(
                        get: { customer.company ?? "" },
                        set: { customer.company = $0.isEmpty ? nil : $0 }
                    ))
                    .focused($focusedField, equals: .company)
                    
                    TextField("Email", text: Binding(
                        get: { customer.email ?? "" },
                        set: { customer.email = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .email)
                    
                    Toggle("Tax Exempt", isOn: $customer.taxExempt)
                }
                
                // ───── Error Message ─────
                if let error = errorMessage {
                    Section {
                        Text("❌ \(error)")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCustomer()
                    }
                    .disabled(isSaving || !canSave)
                }
            }
        }
    }
    
    // ───── Validation ─────
    private var canSave: Bool {
        !customer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !customer.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // ───── Save Customer ─────
    private func saveCustomer() {
        errorMessage = nil
        guard canSave else { return }
        
        isSaving = true
        
        // Update the customer with current timestamp and emoji
        var updatedCustomer = customer
        updatedCustomer.lastModified = Date()
        updatedCustomer.emojiTag = selectedEmoji
        
        CustomerDatabase.shared.updateCustomer(updatedCustomer) { result in
            Task { @MainActor in
                isSaving = false
                switch result {
                case .success:
                    onSave(updatedCustomer)
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}


#Preview {
    CustomerDetailView(customer: Customer.sample)
        .environmentObject(AppState.shared)
}