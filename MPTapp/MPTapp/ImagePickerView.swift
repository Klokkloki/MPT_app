import SwiftUI
import PhotosUI

// MARK: - Image Picker View

struct ImagePickerView: View {
    @Binding var selectedImage: UIImage?
    let title: String
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isLoading = false
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: selectedImage == nil ? "photo.badge.plus" : "photo")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    
                    if selectedImage != nil {
                        Text("Фото выбрано")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Нажмите чтобы выбрать")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if selectedImage != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                await loadImage(from: newItem)
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isLoading = true
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    isLoading = false
                }
            }
        } catch {
            print("Ошибка загрузки изображения: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Custom Image Preview

struct CustomImagePreview: View {
    let image: UIImage?
    let onRemove: () -> Void
    
    var body: some View {
        if let image = image {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.6))
                        )
                }
                .offset(x: 8, y: -8)
            }
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: 120, height: 120)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.3))
                        Text("Нет фото")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                )
        }
    }
}

