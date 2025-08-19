//
//  NetworkMonitor.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/18/25.
//


// NetworkMonitor.swift

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                NotificationCenter.default.post(name: .connectivityStatusChanged, object: nil)
            }
        }
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let connectivityStatusChanged = Notification.Name("connectivityStatusChanged")
}