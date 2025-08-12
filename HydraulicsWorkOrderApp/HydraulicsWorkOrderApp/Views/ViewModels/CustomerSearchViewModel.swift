//
//  CustomerSearchViewModel.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/12/25.
//
// 📄 CustomerSearchViewModel.swift
// Manages customer search state and debounced filtering

import Foundation
import Combine

class CustomerSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var matchingCustomers: [Customer] = []
    @Published var isPickingCustomer: Bool = false

    private var customerDB = CustomerDatabase.shared
    private var searchDebounce: AnyCancellable?

    init() {
        // Prefetch
        customerDB.fetchCustomers()

        // Debounce logic
        searchDebounce = $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }
                guard !self.isPickingCustomer else { return }
                self.handleSearchTextChange(newValue)
            }
    }

    func handleSearchTextChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            matchingCustomers = []
            return
        }

        func digits(_ s: String) -> String { s.filter(\.isNumber) }
        let qLower = trimmed.lowercased()
        let qDigits = digits(trimmed)

        let filtered = customerDB.customers.filter { c in
            let nameHit = c.name.lowercased().contains(qLower)
            let phoneHit: Bool = {
                if qDigits.isEmpty { return false }
                return digits(c.phone).contains(qDigits)
            }()
            return nameHit || phoneHit
        }

        var seen = Set<UUID>()
        let unique = filtered.filter { seen.insert($0.id).inserted }
        let sorted = unique.sorted {
            if $0.name.caseInsensitiveCompare($1.name) == .orderedSame {
                return $0.phone < $1.phone
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        matchingCustomers = Array(sorted.prefix(25))
    }

    func resetSearch() {
        searchText = ""
        matchingCustomers = []
    }
}
