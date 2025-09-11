//
//  DropdownManagerView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

import SwiftUI

// MARK: - DropdownManagerView
struct DropdownManagerView: View {
    @StateObject private var dropdownManager = DropdownManager.shared
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: String = "reasonsForService"
    @State private var showingAddOption = false
    @State private var newOptionLabel = ""
    @State private var newOptionValue = ""
    @State private var showingDeleteConfirmation = false
    @State private var optionToDelete: DropdownOption?
    
    // MARK: - Computed Properties
    private var canEdit: Bool {
        appState.isAdmin || appState.isSuperAdmin
    }
    
    private var canRequestChanges: Bool {
        appState.isManager
    }
    
    private var currentOptions: [DropdownOption] {
        dropdownManager.options[selectedCategory] ?? []
    }
    
    private var categoryDisplayName: String {
        switch selectedCategory {
        case "reasonsForService":
            return "Reasons for Service"
        case "type":
            return "Equipment Type"
        case "size":
            return "Size"
        case "color":
            return "Color"
        case "machineType":
            return "Machine Type"
        case "machineBrand":
            return "Machine Brand"
        case "waitTime":
            return "Wait Time"
        default:
            return selectedCategory.capitalized
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Debug info
            Text("User Role: \(appState.currentUserRole.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            
            // Category Picker
            categoryPicker
            
            // Content based on user role
            if canEdit {
                editableContent
            } else if canRequestChanges {
                readOnlyContentWithRequest
            } else {
                readOnlyContent
            }
        }
        .navigationTitle("Dropdown Manager")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddOption) {
            addOptionSheet
        }
        .alert("Delete Option", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let option = optionToDelete {
                    deleteOption(option)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this option? This action cannot be undone.")
        }
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Category", selection: $selectedCategory) {
                ForEach(orderedCategories, id: \.self) { category in
                    Text(categoryDisplayName(for: category))
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Ordered Categories
    private var orderedCategories: [String] {
        // Reorder categories in logical order
        let preferredOrder = [
            "reasonsForService",
            "type", 
            "size",
            "color",
            "machineType",
            "machineBrand",
            "waitTime"
        ]
        
        let allCategories = Array(dropdownManager.options.keys)
        let ordered = preferredOrder.filter { allCategories.contains($0) }
        let remaining = allCategories.filter { !preferredOrder.contains($0) }
        
        return ordered + remaining.sorted()
    }
    
    // MARK: - Editable Content (Admin/SuperAdmin)
    private var editableContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(categoryDisplayName)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(currentOptions.count) options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Add Option Button
            Button(action: {
                showingAddOption = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add New Option")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal)
            }
            
            // Options List
            List {
                ForEach(currentOptions) { option in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(option.value)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            optionToDelete = option
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveOptions)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    // MARK: - Read-Only Content with Request (Manager)
    private var readOnlyContentWithRequest: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(categoryDisplayName)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(currentOptions.count) options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Action Buttons
            HStack {
                Button(action: {
                    // TODO: Implement request changes functionality
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble")
                        Text("Request Changes")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: {
                    showingAddOption = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Option")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Options List (Read-Only)
            List {
                ForEach(currentOptions) { option in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(option.value)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    // MARK: - Read-Only Content (Tech)
    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(categoryDisplayName)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(currentOptions.count) options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Options List (Read-Only)
            List {
                ForEach(currentOptions) { option in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(option.value)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    // MARK: - Add Option Sheet
    private var addOptionSheet: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Label")
                    .font(.headline)
                TextField("Display name", text: $newOptionLabel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Value")
                    .font(.headline)
                TextField("Internal value", text: $newOptionValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    showingAddOption = false
                    resetNewOptionFields()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add") {
                    addNewOption()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newOptionLabel.isEmpty || newOptionValue.isEmpty)
            }
            .padding()
        }
        .padding()
        .navigationTitle("Add Option")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helper Methods
    private func categoryDisplayName(for category: String) -> String {
        switch category {
        case "reasonsForService":
            return "Reasons for Service"
        case "type":
            return "Equipment Type"
        case "size":
            return "Size"
        case "color":
            return "Color"
        case "machineType":
            return "Machine Type"
        case "machineBrand":
            return "Machine Brand"
        case "waitTime":
            return "Wait Time"
        default:
            return category.capitalized
        }
    }
    
    private func addNewOption() {
        let newOption = DropdownOption(
            label: newOptionLabel,
            value: newOptionValue
        )
        
        dropdownManager.addOption(newOption, to: selectedCategory)
        showingAddOption = false
        resetNewOptionFields()
    }
    
    private func deleteOption(_ option: DropdownOption) {
        dropdownManager.removeOption(option, from: selectedCategory)
        optionToDelete = nil
    }
    
    private func moveOptions(from source: IndexSet, to destination: Int) {
        dropdownManager.moveOptions(from: source, to: destination, in: selectedCategory)
    }
    
    private func resetNewOptionFields() {
        newOptionLabel = ""
        newOptionValue = ""
    }
}

// MARK: - DropdownManager Extensions
extension DropdownManager {
    @MainActor
    func addOption(_ option: DropdownOption, to category: String) {
        if options[category] == nil {
            options[category] = []
        }
        options[category]?.append(option)
        incrementSchemaVersion()
    }
    
    @MainActor
    func removeOption(_ option: DropdownOption, from category: String) {
        options[category]?.removeAll { $0.id == option.id }
        incrementSchemaVersion()
    }
    
    @MainActor
    func moveOptions(from source: IndexSet, to destination: Int, in category: String) {
        options[category]?.move(fromOffsets: source, toOffset: destination)
        incrementSchemaVersion()
    }
    
    @MainActor
    private func incrementSchemaVersion() {
        // Increment the schema version when dropdowns are modified
        DropdownVersionService.shared.incrementVersion()
    }
}

// MARK: - Preview
#Preview {
    DropdownManagerView()
        .environmentObject(AppState.shared)
}
