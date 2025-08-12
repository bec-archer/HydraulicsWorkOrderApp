//
//  AppDelegate.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ───── AppDelegate.swift ─────

import UIKit
import FirebaseCore      // FirebaseApp.configure()
import FirebaseAuth      // Auth.auth()

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("✅ Firebase configured!")
        print("🔎 Auth currentUser (pre‑signIn):", Auth.auth().currentUser?.uid ?? "nil")
        print("🔎 Auth currentUser at launch:", Auth.auth().currentUser?.uid ?? "nil")


        // ───── Anonymous Auth for Firebase Storage (controlled by DevSettings) ─────
        if DevSettingsManager.shared.enableAnonAuth, Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    print("❌ Anonymous sign-in failed:", error.localizedDescription)
                } else if let user = authResult?.user {
                    print("✅ Signed in anonymously as:", user.uid)
                }
            }
        }
        // END Anonymous Auth block

        return true
    }
}
