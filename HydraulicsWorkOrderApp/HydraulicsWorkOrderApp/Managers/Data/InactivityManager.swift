//
//  InactivityManager.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//

import SwiftUI
import Combine
import UIKit

// MARK: - InactivityManager
@MainActor
class InactivityManager: ObservableObject {
    // MARK: - Singleton
    static let shared = InactivityManager()
    
    // MARK: - Published Properties
    @Published var isActive = true
    @Published var timeRemaining: TimeInterval = 60.0
    @Published var showInactivityWarning = false
    
    // MARK: - Private Properties
    private var inactivityTimer: Timer?
    private var warningTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Performance optimization - throttle excessive calls
    private var lastInteractionTime: Date = Date()
    private let interactionThrottleInterval: TimeInterval = 5.0 // Only process interactions every 5 seconds
    private var isInCriticalOperation = false // Flag to disable timeout during critical operations
    
    // Configuration
    private let warningTime: TimeInterval = 10.0 // Show warning 10 seconds before logout
    
    // Get timeout from DevSettingsManager (Admin/SuperAdmin configurable)
    private var inactivityTimeout: TimeInterval {
        DevSettingsManager.shared.inactivityTimeout
    }
    
    // MARK: - Initialization
    private init() {
        setupInactivityMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring for inactivity
    func startMonitoring() {
        resetInactivityTimer()
        setupNotificationObservers()
    }
    
    /// Stop monitoring for inactivity
    func stopMonitoring() {
        invalidateTimers()
        removeNotificationObservers()
    }
    
    /// Reset the inactivity timer (call when user is active)
    func resetInactivityTimer() {
        invalidateTimers()
        
        isActive = true
        timeRemaining = inactivityTimeout
        showInactivityWarning = false
        
        // Start the main inactivity timer
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleInactivityTimeout()
            }
        }
        
        // Start the warning timer
        warningTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout - warningTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showInactivityWarning = true
                self?.startCountdown()
            }
        }
    }
    
    /// Handle user activity (call when user interacts with the app)
    func recordActivity() {
        // Skip all activity tracking during critical operations
        guard !isInCriticalOperation else {
            return
        }
        
        // Throttle excessive calls to prevent performance issues
        let now = Date()
        guard now.timeIntervalSince(lastInteractionTime) >= interactionThrottleInterval else {
            return // Skip this call if it's too soon
        }
        
        lastInteractionTime = now
        print("🔍 DEBUG: InactivityManager.recordActivity called - resetting timer")
        resetInactivityTimer()
    }
    
    /// Extend the session (call when user dismisses warning)
    func extendSession() {
        resetInactivityTimer()
    }
    
    /// Force logout (call when user confirms logout)
    func forceLogout() {
        invalidateTimers()
        performLogout()
    }
    
    /// Start critical operation (disables inactivity timeout)
    func startCriticalOperation() {
        isInCriticalOperation = true
        print("🔍 DEBUG: InactivityManager.startCriticalOperation - disabling timeout")
    }
    
    /// End critical operation (re-enables inactivity timeout)
    func endCriticalOperation() {
        isInCriticalOperation = false
        print("🔍 DEBUG: InactivityManager.endCriticalOperation - re-enabling timeout")
        // Reset the timer when ending critical operation
        resetInactivityTimer()
    }
    
    // MARK: - Private Methods
    
    private func setupInactivityMonitoring() {
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.recordActivity()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { _ in
                // Don't reset timer when app goes to background
                // This allows the timer to continue running
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationObservers() {
        // Monitor for user interactions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserInteraction),
            name: .userInteraction,
            object: nil
        )
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: .userInteraction, object: nil)
    }
    
    @objc private func handleUserInteraction() {
        // Skip all activity tracking during critical operations
        guard !isInCriticalOperation else {
            return
        }
        
        // Throttle excessive calls to prevent performance issues
        let now = Date()
        guard now.timeIntervalSince(lastInteractionTime) >= interactionThrottleInterval else {
            return // Skip this call if it's too soon
        }
        
        lastInteractionTime = now
        print("🔍 DEBUG: InactivityManager.handleUserInteraction called")
        recordActivity()
    }
    
    private func startCountdown() {
        // Start countdown timer for the warning period
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                self.timeRemaining -= 1.0
                
                if self.timeRemaining <= 0 {
                    timer.invalidate()
                    self.handleInactivityTimeout()
                }
            }
        }
    }
    
    private func handleInactivityTimeout() {
        // Don't timeout during critical operations
        guard !isInCriticalOperation else {
            print("🔍 DEBUG: InactivityManager.handleInactivityTimeout - skipping logout during critical operation")
            return
        }
        
        print("🔍 DEBUG: InactivityManager.handleInactivityTimeout called - performing logout")
        isActive = false
        showInactivityWarning = false
        performLogout()
    }
    
    private func performLogout() {
        // Post notification to trigger logout
        NotificationCenter.default.post(name: .inactivityLogout, object: nil)
    }
    
    private func invalidateTimers() {
        inactivityTimer?.invalidate()
        warningTimer?.invalidate()
        inactivityTimer = nil
        warningTimer = nil
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let userInteraction = Notification.Name("userInteraction")
    static let inactivityLogout = Notification.Name("inactivityLogout")
}

// MARK: - User Interaction Tracking
extension InactivityManager {
    /// Track user interaction (call from views when user interacts)
    static func trackUserInteraction() {
        NotificationCenter.default.post(name: .userInteraction, object: nil)
    }
    
    /// Start critical operation (disables inactivity timeout)
    static func startCriticalOperation() {
        shared.startCriticalOperation()
    }
    
    /// End critical operation (re-enables inactivity timeout)
    static func endCriticalOperation() {
        shared.endCriticalOperation()
    }
}

// MARK: - View Modifier for User Interaction Tracking
struct UserInteractionTracking: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                InactivityManager.trackUserInteraction()
            }
            .onLongPressGesture {
                InactivityManager.trackUserInteraction()
            }
            // Remove drag gesture tracking to reduce excessive calls
            // .gesture(
            //     DragGesture()
            //         .onChanged { _ in
            //             InactivityManager.trackUserInteraction()
            //         }
            // )
    }
}

extension View {
    func trackUserInteraction() -> some View {
        modifier(UserInteractionTracking())
    }
}

// MARK: - Inactivity Warning View
struct InactivityWarningView: View {
    @StateObject private var inactivityManager = InactivityManager.shared
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        if inactivityManager.showInactivityWarning {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Timeout Warning")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("You will be logged out in \(Int(inactivityManager.timeRemaining)) seconds due to inactivity.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Button("Extend Session") {
                        inactivityManager.extendSession()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.blue)
                    
                    Button("Logout Now") {
                        inactivityManager.forceLogout()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 8)
            )
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: inactivityManager.showInactivityWarning)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        InactivityWarningView()
            .environmentObject(AppState.shared)
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
