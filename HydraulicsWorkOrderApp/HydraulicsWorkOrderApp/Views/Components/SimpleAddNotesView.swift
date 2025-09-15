import SwiftUI
import Foundation

// MARK: - SimpleAddNotesView
struct SimpleAddNotesView: View {
    let onNotesAdded: (String, [UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var noteText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter note...", text: $noteText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(
                                        Button(action: {
                                            selectedImages.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                        }
                                        .padding(4),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Button("Add Images") {
                    print("🔍 DEBUG: Add Images button tapped")
                    showingImagePicker = true
                    print("🔍 DEBUG: showingImagePicker set to: \(showingImagePicker)")
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onNotesAdded(noteText, selectedImages)
                    }
                    .disabled(noteText.isEmpty && selectedImages.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            SimpleImagePicker(selectedImages: $selectedImages)
        }
    }
}

// MARK: - SimpleImagePicker
struct SimpleImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SimpleImagePicker
        
        init(_ parent: SimpleImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {                                                                    
            print("🔍 DEBUG: Image picker finished picking media")
            if let image = info[.originalImage] as? UIImage {
                print("🔍 DEBUG: Image selected successfully, size: \(image.size)")
                parent.selectedImages.append(image)
                print("🔍 DEBUG: Total selected images: \(parent.selectedImages.count)")
            } else {
                print("🔍 DEBUG: No image found in picker result")
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
