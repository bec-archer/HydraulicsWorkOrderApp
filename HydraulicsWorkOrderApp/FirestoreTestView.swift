//
//  FirestoreTestView.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/8/25.
//


// ───── FirestoreTestView.swift ─────

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct FirestoreTestView: View {
    @State private var message = "⏳ Testing Firebase..."

    var body: some View {
        VStack(spacing: 20) {
            Text("Firebase Test")
                .font(.title)
                .padding()

            Text(message)
                .padding()
                .multilineTextAlignment(.center)

            Button("Try Again", action: runTest)
                .padding()
                .background(Color.yellow)
                .cornerRadius(12)
        }
        .onAppear(perform: runTest)
        // END .body
    }

    // ───── Test Logic ─────
    func runTest() {
        let db = Firestore.firestore()
        let testRef = db.collection("testConnection").document("ping")

        print("🔥 Attempting Firestore write...")

        testRef.setData([
            "timestamp": Timestamp(date: Date()),
            "message": "Hello from HydraulicsWorkOrderApp"
        ]) { error in
            if let error = error {
                print("❌ Write failed: \(error.localizedDescription)")
                message = "❌ Write failed: \(error.localizedDescription)"
                return
            }

            print("✅ Write succeeded. Now reading...")

            testRef.getDocument { snapshot, error in
                if let error = error {
                    print("❌ Read failed: \(error.localizedDescription)")
                    message = "❌ Read failed: \(error.localizedDescription)"
                } else if let data = snapshot?.data() {
                    print("✅ Read success: \(data)")
                    message = "✅ Firebase Connected!\n\n\(data.description)"
                } else {
                    print("⚠️ No data found.")
                    message = "⚠️ No data found."
                }
            }
        }
    }

    // END
}

// ───── Preview Template ─────
#Preview {
    FirestoreTestView()
}
