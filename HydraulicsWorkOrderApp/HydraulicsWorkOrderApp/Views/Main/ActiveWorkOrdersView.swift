//
//  ActiveWorkOrdersView_Refactored.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//
// ─────────────────────────────────────────────────────────────
// 📄 ActiveWorkOrdersView_Refactored.swift
// Refactored version using ActiveWorkOrdersViewModel for better separation of concerns
// ─────────────────────────────────────────────────────────────

import SwiftUI
import Combine

/*  ────────────────────────────────────────────────────────────────────────────
    WARNING — LOCKED VIEW (GUARDRAIL)
    GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT

    This view's layout, UI, and behavior are CRITICAL to the workflow and tests.
    DO NOT change, refactor, or alter layout/styling/functionality in this file.

    Allowed edits ONLY:
      • Comments and documentation
      • Preview sample data (non-shipping)
      • Bugfixes that are 100% no-visual-change (must be verifiable in Preview)

    Any change beyond the above requires explicit approval from Bec.
    Rationale: This screen matches shop SOPs and downstream QA expectations.
    ──────────────────────────────────────────────────────────────────────────── */

// MARK: - ViewModel Integration
// Using dedicated ActiveWorkOrdersViewModel from Views/ViewModels/

// WARNING (GUARDRAIL_TOKEN: DO_NOT_MODIFY_VIEW_LAYOUT):
// Do not alter layout/UI/behavior. See header block for allowed edits & rationale.
struct ActiveWorkOrdersView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel = ActiveWorkOrdersViewModel()
    
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Search & Filter State
    @State private var searchText = ""
    @State private var showTagScanner = false
    @State private var showFilters = false
    
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
    private var filteredActiveWorkOrders: [WorkOrder] {
        var filtered = viewModel.activeWorkOrders
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter(workOrderMatchesSearch)
        }
        
        // Apply dropdown filters
        if hasActiveFilters {
            filtered = filtered.filter(workOrderMatchesFilters)
        }
        
        return filtered
    }
    
    private func workOrderMatchesSearch(_ workOrder: WorkOrder) -> Bool {
        // Search in customer fields
        if workOrder.customerName.localizedCaseInsensitiveContains(searchText) ||
           workOrder.customerPhone.localizedCaseInsensitiveContains(searchText) ||
           (workOrder.customerEmail?.localizedCaseInsensitiveContains(searchText) ?? false) ||
           (workOrder.customerCompany?.localizedCaseInsensitiveContains(searchText) ?? false) ||
           // Search in work order number
           workOrder.workOrderNumber.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        
        // Search in item fields
        return workOrder.items.contains { item in
            item.type.localizedCaseInsensitiveContains(searchText) ||
            (item.assetTagId?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            item.reasonsForService.joined(separator: " ").localizedCaseInsensitiveContains(searchText) ||
            item.dropdowns.values.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func workOrderMatchesFilters(_ workOrder: WorkOrder) -> Bool {
        return workOrder.items.contains { item in
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
    
    private var flaggedWorkOrders: [WorkOrder] {
        filteredActiveWorkOrders.filter { $0.flagged }
    }
    
    private var unflaggedWorkOrders: [WorkOrder] {
        filteredActiveWorkOrders.filter { !$0.flagged }
    }
    
    private var hasActiveFilters: Bool {
        selectedType != nil ||
        selectedColor != nil ||
        selectedSize != nil ||
        selectedMachineType != nil ||
        selectedMachineBrand != nil ||
        selectedWaitTime != nil ||
        !selectedReasons.isEmpty
    }
    
    // MARK: - Body
    var body: some View {
        // Removed debug print to prevent excessive view recreation
        ScrollView {
            VStack(spacing: 20) {
                // Search and Filter Section
                searchAndFilterSection
                // Loading State
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading Active WorkOrders…")
                            .foregroundColor(ThemeManager.shared.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.top, 32)
                }
                
                if !viewModel.isLoading {
                    // Empty State
                    if viewModel.activeWorkOrders.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(ThemeManager.shared.textSecondary)
                            Text("No Active WorkOrders")
                                .font(ThemeManager.shared.labelFont)
                                .foregroundColor(ThemeManager.shared.textPrimary)
                            Text("Tap + New to check one in.")
                                .font(ThemeManager.shared.bodyFont)
                                .foregroundColor(ThemeManager.shared.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .padding(.top, 32)
                    } else {
                        // Work Order Grid with Flagged Sectioning
                        VStack(alignment: .leading, spacing: 20) {
                            // Flagged Section
                            if !flaggedWorkOrders.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "flag.fill")
                                            .foregroundColor(ThemeManager.shared.linkColor)
                                            .font(.headline)
                                        
                                        Text("Flagged")
                                            .font(ThemeManager.shared.labelFont)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(flaggedWorkOrders.count)")
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(ThemeManager.shared.border.opacity(0.3))
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    
                                    GeometryReader { geometry in
                                        let screenWidth = geometry.size.width
                                        let horizontalPadding: CGFloat = 16
                                        let cardSpacing: CGFloat = 16
                                        
                                        // Simple approach: determine cards based on screen width thresholds
                                        let cardsPerRow = screenWidth > 1000 ? 4 : 3
                                        
                                        let availableWidth = screenWidth - (horizontalPadding * 2)
                                        let finalCardWidth = (availableWidth - (cardSpacing * CGFloat(cardsPerRow - 1))) / CGFloat(cardsPerRow)
                                        
                                        // Debug: Print the calculation results
                                        // print("🖥️ Screen width: \(screenWidth)")
                                        // print("📐 Available width: \(availableWidth)")
                                        // print("📊 Cards per row: \(cardsPerRow)")
                                        // print("📏 Final card width: \(finalCardWidth - 32)")
                                        
                                        // Calculate image area size
                                        let imageAreaWidth = finalCardWidth - 32
                                        let imageAreaHeight = min(imageAreaWidth, 200)
                                        let imageAreaSize = min(imageAreaWidth, imageAreaHeight)
                                        
                                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(finalCardWidth - 32), spacing: cardSpacing), count: cardsPerRow), spacing: cardSpacing) {
                                            ForEach(flaggedWorkOrders, id: \.workOrderNumber) { workOrder in
                                                WorkOrderCardView(
                                                    workOrder: workOrder,
                                                    imageAreaSize: imageAreaSize,
                                                    onTap: {
                                                        print("🔍 DEBUG: WorkOrderCardView tapped for WO: \(workOrder.workOrderNumber)")
                                                        appState.navigateToWorkOrderDetail(workOrder)
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // All Active Section
                            if !unflaggedWorkOrders.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "square.grid.2x2")
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                            .font(.headline)
                                        
                                        Text("All Active")
                                            .font(ThemeManager.shared.labelFont)
                                            .foregroundColor(ThemeManager.shared.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(unflaggedWorkOrders.count)")
                                            .font(.caption)
                                            .foregroundColor(ThemeManager.shared.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(ThemeManager.shared.border.opacity(0.3))
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    
                                    GeometryReader { geometry in
                                        let screenWidth = geometry.size.width
                                        let horizontalPadding: CGFloat = 16
                                        let cardSpacing: CGFloat = 16
                                        
                                        // Simple approach: determine cards based on screen width thresholds
                                        let cardsPerRow = screenWidth > 1000 ? 4 : 3
                                        
                                        let availableWidth = screenWidth - (horizontalPadding * 2)
                                        let finalCardWidth = (availableWidth - (cardSpacing * CGFloat(cardsPerRow - 1))) / CGFloat(cardsPerRow)
                                        
                                        // Calculate image area size
                                        let imageAreaWidth = finalCardWidth - 32
                                        let imageAreaHeight = min(imageAreaWidth, 200)
                                        let imageAreaSize = min(imageAreaWidth, imageAreaHeight)
                                        
                                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(finalCardWidth - 32), spacing: cardSpacing), count: cardsPerRow), spacing: cardSpacing) {
                                            ForEach(unflaggedWorkOrders, id: \.workOrderNumber) { workOrder in
                                                WorkOrderCardView(
                                                    workOrder: workOrder,
                                                    imageAreaSize: imageAreaSize,
                                                    onTap: {
                                                        print("🔍 DEBUG: WorkOrderCardView tapped for WO: \(workOrder.workOrderNumber)")
                                                        appState.navigateToWorkOrderDetail(workOrder)
                                                    }
                                                )
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
        .navigationTitle("Active WorkOrders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    print("🔍 DEBUG: Plus button tapped in ActiveWorkOrdersView")
                    print("🔍 DEBUG: Current appState.currentView: \(appState.currentView)")
                    print("🔍 DEBUG: Setting appState.currentView to .newWorkOrder")
                    appState.currentView = .newWorkOrder
                    print("🔍 DEBUG: New appState.currentView: \(appState.currentView)")
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(ThemeManager.shared.linkColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Work Order")
            }
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
            // ViewModel already loads work orders in init(), no need to call again
            print("🔍 DEBUG: ActiveWorkOrdersView appeared")
        }
    }
    
    // MARK: - Search and Filter UI Components
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                TextField("Search customers, work orders, tags...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                // Filter Button
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(hasActiveFilters ? ThemeManager.shared.linkColor : ThemeManager.shared.textSecondary)
                }
                
                // Tag Scanner Button
                Button {
                    showTagScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(ThemeManager.shared.linkColor)
                }
            }
            .padding(.horizontal)
            
            // Active Filter Chips
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
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var filterSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Filter Active Work Orders")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    // Filter Options - Three Column Layout
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ThemeManager.shared.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ThemeManager.shared.border, lineWidth: 1)
        )
    }
    
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
        for reason in selectedReasons {
            chips.append("Reason: \(reason)")
        }
        
        return chips
    }
    
    private func clearFilter(_ chip: String) {
        if chip.hasPrefix("Type: ") {
            selectedType = nil
        } else if chip.hasPrefix("Color: ") {
            selectedColor = nil
        } else if chip.hasPrefix("Size: ") {
            selectedSize = nil
        } else if chip.hasPrefix("Machine: ") {
            selectedMachineType = nil
        } else if chip.hasPrefix("Brand: ") {
            selectedMachineBrand = nil
        } else if chip.hasPrefix("Wait: ") {
            selectedWaitTime = nil
        } else if chip.hasPrefix("Reason: ") {
            let reason = String(chip.dropFirst(8)) // Remove "Reason: " prefix
            selectedReasons.remove(reason)
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
        ActiveWorkOrdersView()
    }
    .environmentObject(AppState.shared)
}