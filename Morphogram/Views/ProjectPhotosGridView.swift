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
    @State private var isEditing = false
    @State private var itemSize: CGSize = .zero
    private static let initialGridCount = 3
    @Environment(\.modelContext) private var modelContext
    
    @State var columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: initialGridCount)
    
    var body: some View {
        VStack {
            if isEditing {
                ColumnStepper(title: "Kolon: \(columns.count)", range: 1...6, columns: $columns)
                .padding()
            }
            ScrollView {
                LazyVGrid(columns: columns) {
                    
                    if !isEditing {
                        Button(action: {
                            showCamera = true
                        }) {
                            VStack {
                                Image(systemName: "camera.fill")
                                    .frame(width: itemSize.width, height: itemSize.width)
                                    .font(.system(size: 44))
                                    .foregroundColor(.accentColor)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    ForEach(Array(project.photos.sorted(by: { $0.createdAt > $1.createdAt }).enumerated()), id: \.element.id) { index, photo in
                        GeometryReader { geo in
                            if let fileName = photo.fileName {
                                ZStack(alignment: .topTrailing) {
                                    AsyncImageView(fileName: fileName)
                                        .frame(width: geo.size.width, height: geo.size.width)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .onAppear {
                                    itemSize = geo.size
                                }
                                .onChange(of: itemSize) { _, newSize in
                                    itemSize = newSize
                                }
                                .contextMenu {
                                    Button {
                                        selectedPhotoIndex = index
                                        isFullscreenPresented = true
                                    } label: {
                                        Label("Tam Ekran Görüntüle", systemImage: "arrow.up.left.and.arrow.down.right")
                                    }
                                    
                                    Button(role: .destructive) {
                                        deletePhoto(photo)
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                } preview: {
                                    if let fileName = photo.fileName {
                                        AsyncImageView(fileName: fileName)
                                            .frame(maxWidth: 300, maxHeight: 300)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Text(formatDate(photo.createdAt))
                                .font(.caption)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                                .padding(4),
                            alignment: .bottom
                        )
                        .overlay(alignment: .topTrailing, content: {
                            if isEditing {
                                Button(action: {
                                    deletePhoto(photo)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .offset(x: 7, y: -7)
                            }
                        })
                        .onTapGesture {
                            if !isEditing {
                                selectedPhotoIndex = index
                                isFullscreenPresented = true
                            }
                        }
                        .wiggle(isActive: isEditing)
                    }
                }
                .padding()
            }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }) {
                        Text(isEditing ? "Bitti" : "Düzenle")
                    }
                    .disabled(project.photos.isEmpty)
                }
            }
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
