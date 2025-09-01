import SwiftUI

struct DataMigrationView: View {
    @StateObject private var migrationService = DataMigrationService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Database Migration")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("This will clear all test data and prepare for a fresh start")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Warning
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Warning")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    Text("This action will permanently delete ALL work orders and customer data from Firebase. This cannot be undone.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                
                // Image Deletion Option
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                        Text("Image Handling")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Toggle("Also delete all images from Firebase Storage", isOn: $migrationService.shouldDeleteImages)
                        .font(.body)
                    
                    Text(migrationService.shouldDeleteImages ? 
                         "Images will be permanently deleted from Firebase Storage." :
                         "Images will remain in Firebase Storage but become orphaned (not accessible).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Migration Status
                if migrationService.isMigrating {
                    VStack(spacing: 16) {
                        ProgressView(value: migrationService.migrationProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        
                        Text(migrationService.migrationStatus)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await migrationService.migrateAndClearDatabase()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Test Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(migrationService.isMigrating)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .disabled(migrationService.isMigrating)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .navigationTitle("Migration")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(migrationService.isMigrating)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !migrationService.isMigrating {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onChange(of: migrationService.migrationProgress) { _, progress in
            if progress >= 1.0 {
                // Migration completed, dismiss after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    DataMigrationView()
}
