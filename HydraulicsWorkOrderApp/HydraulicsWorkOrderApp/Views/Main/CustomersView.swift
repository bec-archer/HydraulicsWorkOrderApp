//
//  CustomersView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI
import UIKit

// ─────────────────────────────────────────────────────────────
// 📄 CustomersView.swift
// Displays a searchable list of customers with navigation to details
// ─────────────────────────────────────────────────────────────

struct CustomersView: View {
    @StateObject private var customerDatabase = CustomerDatabase.shared
    @State private var searchText = ""
    @State private var selectedCustomer: Customer?
    @State private var showingPhoneActions = false
    @State private var selectedPhoneNumber = ""
    @State private var selectedCustomerName = ""
    
    var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customerDatabase.customers
        } else {
            return customerDatabase.searchCustomers(matching: searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search customers by name, phone, or company")
                    .padding(.horizontal)
                    .padding(.top)
                
                // Customers list
                List(filteredCustomers, id: \.id) { customer in
                    CustomerRowView(
                        customer: customer,
                        onPhoneTap: { phoneNumber, customerName in
                            selectedPhoneNumber = phoneNumber
                            selectedCustomerName = customerName
                            showingPhoneActions = true
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCustomer = customer
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Customers")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedCustomer) { customer in
                CustomerDetailView(customer: customer)
            }
            .alert("Choose how to contact \(selectedCustomerName.isEmpty ? "Customer" : selectedCustomerName)", isPresented: $showingPhoneActions) {
                Button("Call \(selectedPhoneNumber)") {
                    let phoneNumber = digitsOnly(selectedPhoneNumber)
                    let telURL = URL(string: "tel://\(phoneNumber)")
                    
                    if let telURL = telURL {
                        UIApplication.shared.open(telURL) { success in
                            if !success {
                                // Copy number to clipboard as fallback
                                UIPasteboard.general.string = phoneNumber
                            }
                        }
                    }
                }
                
                Button("Text \(selectedPhoneNumber)") {
                    let phoneNumber = digitsOnly(selectedPhoneNumber)
                    let smsURL = URL(string: "sms://\(phoneNumber)")
                    
                    if let smsURL = smsURL {
                        UIApplication.shared.open(smsURL) { success in
                            if !success {
                                // Copy number to clipboard as fallback
                                UIPasteboard.general.string = phoneNumber
                            }
                        }
                    }
                }
                
                Button("Copy Number", role: .none) {
                    let phoneNumber = digitsOnly(selectedPhoneNumber)
                    UIPasteboard.general.string = phoneNumber
                }
                
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Select an action to contact this customer")
            }
            .onChange(of: showingPhoneActions) { _, isShowing in
                if !isShowing {
                    // Reset the selected customer info when dialog is dismissed
                    selectedPhoneNumber = ""
                    selectedCustomerName = ""
                }
            }
            .onAppear {
                customerDatabase.fetchCustomers()
            }
        }
    }
    
    // MARK: - Helper Functions
    private func digitsOnly(_ string: String) -> String {
        return string.filter { $0.isNumber }
    }
}

// MARK: - Customer Row View
struct CustomerRowView: View {
    let customer: Customer
    let onPhoneTap: (String, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let company = customer.company, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(customer.phone)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#FFC500"))
                        .underline()
                        .onLongPressGesture {
                            onPhoneTap(customer.phone, customer.name)
                        }
                    
                    if customer.taxExempt {
                        Text("Tax Exempt")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            if let email = customer.email, !email.isEmpty {
                Text(email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}



// MARK: - Preview
#Preview {
    CustomersView()
        .environmentObject(AppState.shared)
}
