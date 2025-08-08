//
//  NewCustomerModalView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ─────────────────────────────────────────────────────────────
// 📄 NewCustomerModalView.swift
// Used to create a new Customer and return it to parent view
// ─────────────────────────────────────────────────────────────

import SwiftUI

struct NewCustomerModalView: View {
    @Environment(\.dismiss) var dismiss

    // Prefilled from search
    @State var prefillName: String
    @State var prefillPhone: String

    // Output
    @Binding var selectedCustomer: Customer?

    // Fields
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var company: String = ""
    @State private var email: String = ""
    @State private var taxExempt: Bool = false

    // Feedback
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Customer Info")) {
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Full Name", text: $name)
                }

                Section(header: Text("Optional Info")) {
                    TextField("Company", text: $company)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    Toggle("Tax Exempt", isOn: $taxExempt)
                }

                if let error = errorMessage {
                    Section {
                        Text("❌ \(error)")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button("Save Customer") {
                        saveCustomer()
                    }
                    .disabled(isSaving || name.isEmpty || phone.isEmpty)
                }
            }
            .navigationTitle("New Customer")
            .onAppear {
                name = prefillName
                phone = prefillPhone
            }
        }
        // END .body
    }

    // ───── Save to Firebase ─────
    func saveCustomer() {
        isSaving = true
        let newCustomer = Customer(
            id: nil,
            name: name,
            phone: phone,
            company: company.isEmpty ? nil : company,
            email: email.isEmpty ? nil : email,
            taxExempt: taxExempt
        )

        CustomerDatabase.shared.addCustomer(newCustomer) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    selectedCustomer = newCustomer
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // END
}

// ───── Preview Template ─────

#Preview(traits: .sizeThatFitsLayout) {
    NewCustomerModalView(prefillName: "Maria", prefillPhone: "555-1234", selectedCustomer: .constant(nil))
}
