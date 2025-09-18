//
//  ClosedWorkOrdersView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Assistant on 1/9/25.
//
//  View for displaying closed work orders - accessible by SuperAdmin, Admin, and Manager roles
//  Reuses ActiveWorkOrdersView with a filter for closed work orders only

import SwiftUI

struct ClosedWorkOrdersView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = ActiveWorkOrdersViewModel()
    
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Search & Filter State
    @State private var searchText = ""
    @State private var showTagScanner = false
    @Binding var showFilters: Bool
    
    // Filter states
    @State private var selectedType: String? = nil
    @State private var selectedColor: String? = nil
    @State private var selectedSize: String? = nil
    @State private var selectedMachineType: String? = nil
    @State private var selectedMachineBrand: String? = nil
    @State private var selectedWaitTime: String? = nil
    @State private var selectedReasons: Set<String> = []
    @State private var customColor = Color.clear
    
    // MARK: - Computed Properties
    private var allClosedWorkOrders: [WorkOrder] {
        // Use raw work orders from database, not the filtered activeWorkOrders
        viewModel.workOrders.filter { $0.isClosed && !$0.isDeleted }
    }
    
    private var filteredClosedWorkOrders: [WorkOrder] {
        var filtered = allClosedWorkOrders
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { workOrder in
                // Search in customer fields
                workOrder.customerName.localizedCaseInsensitiveContains(searchText) ||
                workOrder.customerPhone.localizedCaseInsensitiveContains(searchText) ||
                (workOrder.customerCompany?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                workOrder.workOrderNumber.localizedCaseInsensitiveContains(searchText) ||
                // Search in item fields
                workOrder.items.contains { item in
                    item.type.localizedCaseInsensitiveContains(searchText) ||
                    (item.assetTagId?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    item.dropdowns.values.contains { $0.localizedCaseInsensitiveContains(searchText) }
                }
            }
        }
        
        // Apply dropdown filters
        filtered = filtered.filter { workOrder in
            workOrder.items.contains { item in
                var matches = true
                
                if let type = selectedType {
                    matches = matches && (item.type == type || item.dropdowns["type"] == type)
                }
                if let color = selectedColor {
                    matches = matches && item.dropdowns["color"] == color
                }
                if let size = selectedSize {
                    matches = matches && item.dropdowns["size"] == size
                }
                if let machineType = selectedMachineType {
                    matches = matches && item.dropdowns["machineType"] == machineType
                }
                if let machineBrand = selectedMachineBrand {
                    matches = matches && item.dropdowns["machineBrand"] == machineBrand
                }
                if let waitTime = selectedWaitTime {
                    matches = matches && item.dropdowns["waitTime"] == waitTime
                }
                if !selectedReasons.isEmpty {
                    matches = matches && !Set(item.reasonsForService).isDisjoint(with: selectedReasons)
                }
                
                return matches
            }
        }
        
        return filtered
    }
    
    private var flaggedClosedWorkOrders: [WorkOrder] {
        filteredClosedWorkOrders.filter { $0.flagged }
    }
    
    private var unflaggedClosedWorkOrders: [WorkOrder] {
        filteredClosedWorkOrders.filter { !$0.flagged }
    }
    
    private var hasActiveFilters: Bool {
        selectedType != nil || selectedColor != nil || selectedSize != nil ||
        selectedMachineType != nil || selectedMachineBrand != nil ||
        selectedWaitTime != nil || !selectedReasons.isEmpty
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Section
            searchAndFilterSection
            
            // Main Content
            ScrollView {
                VStack(spacing: 20) {
                    // Loading State
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading Closed WorkOrders…")
                                .foregroundColor(ThemeManager.shared.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .padding(.top, 32)
                    }
                    
                    if !viewModel.isLoading {
                        // Empty State
                        if filteredClosedWorkOrders.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "archivebox")
                                    .font(.largeTitle)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                                Text(hasActiveFilters ? "No Matching WorkOrders" : "No Closed WorkOrders")
                                    .font(ThemeManager.shared.labelFont)
                                    .foregroundColor(ThemeManager.shared.textPrimary)
                                Text(hasActiveFilters ? "Try adjusting your search or filters." : "Closed work orders will appear here.")
                                    .font(ThemeManager.shared.bodyFont)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 240)
                            .padding(.top, 32)
                        } else {
                            // Work Order Grid with Flagged Sectioning
                            VStack(alignment: .leading, spacing: 20) {
                                // Flagged Section
                                if !flaggedClosedWorkOrders.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "flag.fill")
                                                .foregroundColor(ThemeManager.shared.linkColor)
                                                .font(.headline)
                                            
                                            Text("Flagged Closed")
                                                .font(ThemeManager.shared.labelFont)
                                                .foregroundColor(ThemeManager.shared.textPrimary)
                                            
                                            Spacer()
                                            
                                            Text("\(flaggedClosedWorkOrders.count)")
                                                .font(.caption)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(ThemeManager.shared.border.opacity(0.3))
                                                .cornerRadius(8)
                                        }
                                        .padding(.horizontal)
                                        
                                        LazyVGrid(columns: [
                                            GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16)
                                        ], spacing: 16) {
                                            ForEach(flaggedClosedWorkOrders, id: \.workOrderNumber) { workOrder in
                                                WorkOrderCardView(workOrder: workOrder, imageAreaSize: 200)
                                                    .onTapGesture {
                                                        appState.navigateToWorkOrderDetail(workOrder)
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // All Closed Section
                                if !unflaggedClosedWorkOrders.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "archivebox")
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                                .font(.headline)
                                            
                                            Text("All Closed")
                                                .font(ThemeManager.shared.labelFont)
                                                .foregroundColor(ThemeManager.shared.textPrimary)
                                            
                                            Spacer()
                                            
                                            Text("\(unflaggedClosedWorkOrders.count)")
                                                .font(.caption)
                                                .foregroundColor(ThemeManager.shared.textSecondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(ThemeManager.shared.border.opacity(0.3))
                                                .cornerRadius(8)
                                        }
                                        .padding(.horizontal)
                                        
                                        LazyVGrid(columns: [
                                            GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16)
                                        ], spacing: 16) {
                                            ForEach(unflaggedClosedWorkOrders, id: \.workOrderNumber) { workOrder in
                                                WorkOrderCardView(workOrder: workOrder, imageAreaSize: 200)
                                                    .onTapGesture {
                                                        appState.navigateToWorkOrderDetail(workOrder)
                                                    }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            viewModel.refreshWorkOrders()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showTagScanner) {
            TagScanningView(isPresented: $showTagScanner)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showFilters) {
            filterSheet
        }
        .onAppear {
            viewModel.loadWorkOrders()
        }
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ThemeManager.shared.textSecondary)
                    
                    TextField("Search customers, work orders, tags...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ThemeManager.shared.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ThemeManager.shared.border, lineWidth: 1)
                )
                
                // Filter Button
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(hasActiveFilters ? ThemeManager.shared.linkColor : ThemeManager.shared.textSecondary)
                        .cornerRadius(8)
                }
                
                // Tag Scanner Button
                Button {
                    showTagScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(ThemeManager.shared.linkColor)
                        .cornerRadius(8)
                }
            }
            
            // Active Filters Summary
            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeFilterChips, id: \.self) { chip in
                            HStack(spacing: 4) {
                                Text(chip)
                                    .font(.caption)
                                Button {
                                    clearFilter(chip)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ThemeManager.shared.linkColor.opacity(0.1))
                            .foregroundColor(ThemeManager.shared.linkColor)
                            .cornerRadius(12)
                        }
                        
                        Button("Clear All") {
                            clearAllFilters()
                        }
                        .font(.caption)
                        .foregroundColor(ThemeManager.shared.textSecondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(ThemeManager.shared.cardBackground)
    }
    
    // MARK: - Filter Sheet
    private var filterSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Filter Title
                    Text("Filter Closed Work Orders")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    // Filter Options - Three Column Layout (reorganized)
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        // Column 1: Type, Machine Type
                        filterSection(title: "Type", options: DropdownManager.shared.options["type"] ?? []) {
                            DropdownField(
                                label: "Type",
                                options: DropdownManager.shared.options["type"] ?? [],
                                selectedValue: $selectedType,
                                showColorPickerIfOther: false,
                                customColor: $customColor,
                                placeholder: "All Types"
                            )
                        }
                        
                        filterSection(title: "Machine Type", options: DropdownManager.shared.options["machineType"] ?? []) {
                            DropdownField(
                                label: "Machine Type",
                                options: DropdownManager.shared.options["machineType"] ?? [],
                                selectedValue: $selectedMachineType,
                                showColorPickerIfOther: false,
                                customColor: $customColor,
                                placeholder: "All Machine Types"
                            )
                        }
                        
                        // Column 2: Color, Wait Time
                        filterSection(title: "Color", options: DropdownManager.shared.options["color"] ?? []) {
                            DropdownField(
                                label: "Color",
                                options: DropdownManager.shared.options["color"] ?? [],
                                selectedValue: $selectedColor,
                                showColorPickerIfOther: true,
                                customColor: $customColor,
                                placeholder: "All Colors"
                            )
                        }
                        
                        filterSection(title: "Wait Time", options: DropdownManager.shared.options["waitTime"] ?? []) {
                            DropdownField(
                                label: "Wait Time",
                                options: DropdownManager.shared.options["waitTime"] ?? [],
                                selectedValue: $selectedWaitTime,
                                showColorPickerIfOther: false,
                                customColor: $customColor,
                                placeholder: "All Wait Times"
                            )
                        }
                        
                        // Column 3: Size, Machine Brand
                        filterSection(title: "Size", options: DropdownManager.shared.options["size"] ?? []) {
                            DropdownField(
                                label: "Size",
                                options: DropdownManager.shared.options["size"] ?? [],
                                selectedValue: $selectedSize,
                                showColorPickerIfOther: false,
                                customColor: $customColor,
                                placeholder: "All Sizes"
                            )
                        }
                        
                        filterSection(title: "Machine Brand", options: DropdownManager.shared.options["machineBrand"] ?? []) {
                            DropdownField(
                                label: "Machine Brand",
                                options: DropdownManager.shared.options["machineBrand"] ?? [],
                                selectedValue: $selectedMachineBrand,
                                showColorPickerIfOther: false,
                                customColor: $customColor,
                                placeholder: "All Brands"
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Service Reason Section - Full Width
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Reason")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ThemeManager.shared.textPrimary)
                        
                        multiSelectServiceReasonField
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        clearAllFilters()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFilters = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func filterSection<Content: View>(title: String, options: [DropdownOption], @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(ThemeManager.shared.textPrimary)
            
            content()
        }
        .padding()
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ThemeManager.shared.border, lineWidth: 1)
        )
    }
    
    // MARK: - Helper Properties
    private var multiSelectServiceReasonField: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show selected reasons as chips
            if !selectedReasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(selectedReasons.sorted()), id: \.self) { reason in
                        HStack {
                            Text(reason)
                                .font(.caption)
                            Spacer()
                            Button {
                                selectedReasons.remove(reason)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(ThemeManager.shared.textSecondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ThemeManager.shared.linkColor.opacity(0.1))
                        .foregroundColor(ThemeManager.shared.linkColor)
                        .cornerRadius(6)
                    }
                }
            }
            
            // Direct selection buttons for each reason
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(DropdownManager.shared.options["reasonsForService"] ?? [], id: \.value) { option in
                    Button {
                        if selectedReasons.contains(option.value) {
                            selectedReasons.remove(option.value)
                        } else {
                            selectedReasons.insert(option.value)
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                                .font(.caption)
                                .lineLimit(1)
                            if selectedReasons.contains(option.value) {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(selectedReasons.contains(option.value) ? .white : ThemeManager.shared.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(selectedReasons.contains(option.value) ? ThemeManager.shared.linkColor : ThemeManager.shared.cardBackground)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ThemeManager.shared.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var activeFilterChips: [String] {
        var chips: [String] = []
        
        if let type = selectedType {
            chips.append("Type: \(type)")
        }
        if let color = selectedColor {
            chips.append("Color: \(color)")
        }
        if let size = selectedSize {
            chips.append("Size: \(size)")
        }
        if let machineType = selectedMachineType {
            chips.append("Machine: \(machineType)")
        }
        if let machineBrand = selectedMachineBrand {
            chips.append("Brand: \(machineBrand)")
        }
        if let waitTime = selectedWaitTime {
            chips.append("Wait: \(waitTime)")
        }
        if !selectedReasons.isEmpty {
            chips.append("Reasons: \(selectedReasons.count)")
        }
        
        return chips
    }
    
    // MARK: - Helper Methods
    private func clearFilter(_ chip: String) {
        if chip.hasPrefix("Type:") {
            selectedType = nil
        } else if chip.hasPrefix("Color:") {
            selectedColor = nil
        } else if chip.hasPrefix("Size:") {
            selectedSize = nil
        } else if chip.hasPrefix("Machine:") {
            selectedMachineType = nil
        } else if chip.hasPrefix("Brand:") {
            selectedMachineBrand = nil
        } else if chip.hasPrefix("Wait:") {
            selectedWaitTime = nil
        } else if chip.hasPrefix("Reasons:") {
            selectedReasons.removeAll()
        }
    }
    
    private func clearAllFilters() {
        selectedType = nil
        selectedColor = nil
        selectedSize = nil
        selectedMachineType = nil
        selectedMachineBrand = nil
        selectedWaitTime = nil
        selectedReasons.removeAll()
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ClosedWorkOrdersView(showFilters: .constant(false))
    }
    .environmentObject(AppState.shared)
}