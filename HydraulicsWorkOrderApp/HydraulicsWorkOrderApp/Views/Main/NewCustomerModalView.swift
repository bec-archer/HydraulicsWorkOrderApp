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
    // ───── ENV ─────
    @Environment(\.dismiss) private var dismiss

    // ───── INPUT (Prefilled from search) ─────
    let prefillName: String
    let prefillPhone: String

    // ───── OUTPUT (Parent binding) ─────
    @Binding var selectedCustomer: Customer?

    // ───── FIELDS ─────
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var company: String = ""
    @State private var email: String = ""
    @State private var taxExempt: Bool = false

    // ───── FEEDBACK ─────
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false
    @FocusState private var focusedField: Field?

    enum Field { case phone, name, company, email }

    // ───── BODY ─────
    var body: some View {
        NavigationStack {
            Form {
                // ───── Customer Info ─────
                Section(header: Text("Customer Info")) {
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focusedField, equals: .phone)

                    TextField("Full Name", text: $name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                }
                // END Section

                // ───── Optional Info ─────
                Section(header: Text("Optional Info")) {
                    TextField("Company", text: $company)
                        .focused($focusedField, equals: .company)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)

                    Toggle("Tax Exempt", isOn: $taxExempt)
                }
                // END Section

                // ───── Error State ─────
                if let error = errorMessage {
                    Section {
                        Text("❌ \(error)")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                // END Section

                // ───── Actions ─────
                Section {
                    Button {
                        saveCustomer()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Customer")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !canSave)
                }
                // END Section
            }
            .navigationTitle("New Customer")
            .toolbar { // ───── Toolbar ─────
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { // ───── Prefill on Appear ─────
                name = prefillName
                phone = prefillPhone
                // Focus the first empty field
                if phone.isEmpty { focusedField = .phone }
                else if name.isEmpty { focusedField = .name }
            }
        }
        // END NavigationStack
    }
    // END .body

    // ───── Derived Validation ─────
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !phoneDigits.isEmpty
    }

    private var phoneDigits: String {
        phone.filter(\.isNumber)
    }
    // END Validation

    // ───── Save to Database ─────
    private func saveCustomer() {
        errorMessage = nil
        guard canSave else { return }
        isSaving = true

        // ───── Create model (UUID id in-app; DB uses uuidString for doc id) ─────
        // ───── Create model (UUID id + all required fields) ─────
        let newCustomer = Customer(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phoneDigits,
            company: company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : company,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : email,
            taxExempt: taxExempt
        )


        // ───── Persistence Call ─────
        CustomerDatabase.shared.addCustomer(newCustomer) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    print("✅ NewCustomerModalView SAVED:", newCustomer.id, newCustomer.name, newCustomer.phone) // TEMP LOG
                    selectedCustomer = newCustomer
                    print("🔁 NewCustomerModalView INJECTED BACK TO PARENT") // TEMP LOG
                    dismiss()
                case .failure(let error):
                    print("🛑 NewCustomerModalView SAVE FAILED:", error.localizedDescription) // TEMP LOG
                    errorMessage = error.localizedDescription
                }
            }
        }
        // END Persistence Call

    }
    // END Save
}
// END NewCustomerModalView


// ─────────────────────────────────────────────────────────────
// MARK: - Preview Template
// ─────────────────────────────────────────────────────────────
#Preview(traits: .sizeThatFitsLayout) {
    NewCustomerModalView(
        prefillName: "Maria",
        prefillPhone: "555-1234",
        selectedCustomer: .constant(nil)
    )
}
// END Preview
