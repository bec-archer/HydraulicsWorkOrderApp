//
//  CustomersView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 9/2/25.
//

// ───── CUSTOMERS VIEW ─────
import SwiftUI

/// Shows a list of all customers with search functionality
struct CustomersView: View {
    @StateObject private var customerDB = CustomerDatabase.shared
    @State private var searchText = ""
    @State private var showingAddCustomer = false
    @State private var showTaxExemptOnly = false
    @State private var showTop20Only = false
    
    private var filteredCustomers: [Customer] {
        var customers = customerDB.customers
        
        // Apply search filter
        if !searchText.isEmpty {
            customers = customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.phoneNumber.localizedCaseInsensitiveContains(searchText) ||
                (customer.company?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply tax exempt filter
        if showTaxExemptOnly {
            customers = customers.filter { $0.taxExempt }
        }
        
        // Apply top 20 filter (by work order count)
        if showTop20Only {
            // TODO: Replace with actual WorkOrdersDatabase lookup for customer work order counts
            // For now, show first 20 customers
            customers = Array(customers.prefix(20))
        }
        
        return customers
    }
    
    var body: some View {
        // ───── BODY ─────
        NavigationStack {
            VStack {
                if customerDB.customers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Customers Found")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Add your first customer to get started.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Add Customer") {
                            showingAddCustomer = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredCustomers) { customer in
                            NavigationLink(destination: CustomerDetailView(customer: customer)) {
                                CustomerRow(customer: customer)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Customers")
            .searchable(text: $searchText, prompt: "Search customers...")
            .safeAreaInset(edge: .top) {
                VStack(spacing: 8) {
                    // Header row with Add New Customer button
                    HStack {
                        Spacer()
                        
                        Button("+ Add New Customer") {
                            showingAddCustomer = true
                        }
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 1.0, green: 0.773, blue: 0.0)) // #FFC500
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.top, 0)
                    
                    // Filter buttons row
                    HStack(spacing: 12) {
                        Button(action: {
                            showTaxExemptOnly.toggle()
                            showTop20Only = false // Reset other filter
                        }) {
                            HStack {
                                Image(systemName: showTaxExemptOnly ? "checkmark.shield.fill" : "checkmark.shield")
                                Text("Tax Exempt")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(showTaxExemptOnly ? Color.green : Color.gray.opacity(0.2))
                            .foregroundStyle(showTaxExemptOnly ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            showTop20Only.toggle()
                            showTaxExemptOnly = false // Reset other filter
                        }) {
                            HStack {
                                Image(systemName: showTop20Only ? "star.fill" : "star")
                                Text("Top 20")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(showTop20Only ? Color.orange : Color.gray.opacity(0.2))
                            .foregroundStyle(showTop20Only ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        if showTaxExemptOnly || showTop20Only {
                            Button("Clear Filters") {
                                showTaxExemptOnly = false
                                showTop20Only = false
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .background(.background)
            }
            .sheet(isPresented: $showingAddCustomer) {
                NewCustomerModalView(
                    prefillName: "",
                    prefillPhone: "",
                    selectedCustomer: .constant(nil)
                )
            }
            .onAppear {
                customerDB.fetchCustomers()
            }
        }
        // END
    }
}

// MARK: - Supporting Views

/// Row view for displaying a customer in the list
private struct CustomerRow: View {
    let customer: Customer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(customer.name)
                    .font(.headline)
                Spacer()
                // Customer tag removed from model
            }
            
            Text(customer.phoneNumber.formattedPhoneNumber)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let company = customer.company, !company.isEmpty {
                Text(company)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if customer.taxExempt {
                HStack {
                    Image(systemName: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Tax Exempt")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// ───── PREVIEW ─────
#Preview {
    CustomersView()
}
// END
