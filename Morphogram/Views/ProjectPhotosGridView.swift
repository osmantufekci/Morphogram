//
//  ProjectPhotosGridView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//

import SwiftUI
import SwiftData

struct ProjectPhotosGridView: View {
    let project: Project
    @State private var selectedPhotoIndex: Int?
    @State private var isFullscreenPresented = false
    @State private var showCamera = false
    @Environment(\.modelContext) private var modelContext
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                // Kamera butonu
                Button(action: {
                    showCamera = true
                }) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.accentColor)
                            .frame(width: 125, height: 125)
                            .background(Color.black.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // Fotoğraf listesi
                ForEach(Array(project.photos.sorted(by: { $0.createdAt > $1.createdAt }).enumerated()), id: \.element.id) { index, photo in
                    if let fileName = photo.fileName {
                        AsyncImageView(fileName: fileName)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: 125, maxHeight: 125)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                Text(formatDate(photo.createdAt))
                                    .font(.caption)
                                    .padding(4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(4)
                                    .padding(4),
                                alignment: .bottom
                            )
                            .onTapGesture {
                                selectedPhotoIndex = index
                                isFullscreenPresented = true
                            }
                    }
                }
            }
            .padding(8)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isFullscreenPresented) {
            FullscreenPhotoView(
                photos: project.photos.sorted(by: { $0.createdAt > $1.createdAt }),
                initialIndex: selectedPhotoIndex ?? 0,
                isPresented: $isFullscreenPresented,
                onDelete: { photo in
                    deletePhoto(photo)
                }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(project: project)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func deletePhoto(_ photo: ProjectPhoto) {
        if let fileName = photo.fileName {
            // Dosyayı sil
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = documentsPath.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: filePath)
        }
        
        // Fotoğrafı projeden kaldır
        project.photos.removeAll { $0.id == photo.id }
        
        // SwiftData'dan sil
        modelContext.delete(photo)
        
        try? modelContext.save()
    }
}
