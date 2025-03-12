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
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var showAddSheet = false
    @State private var isEditing = false
    @State private var itemSize: CGSize = .zero
    @State private var isLoading = false
    @State private var progress: Float = 0
    @State private var totalPhotos: Int = 0
    @State private var selectedPhotos: Set<ProjectPhoto> = []
    @State private var showDeleteConfirmation = false
    private static let initialGridCount = 3
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var router: NavigationManager
    @Namespace private var zoomTransition
    
    @State var columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: initialGridCount)
    
    var body: some View {
        ZStack {
            VStack {
                if isEditing {
                    HStack {
                        ColumnStepper(title: "Kolon Adedi: \(columns.count)", range: 1...6, columns: $columns)
                    }
                    .padding()
                }
                ScrollView {
                    LazyVGrid(columns: columns) {
                        if !isEditing {
                            Button(action: {
                                showAddSheet = true
                            }) {
                                VStack {
                                    Image(systemName: "plus.circle.fill")
                                        .frame(width: project.photos.isEmpty ? 125 : itemSize.width, height: project.photos.isEmpty ? 125 : itemSize.width)
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
                                        AsyncImageView(fileName: fileName, loadFullResolution: false)
                                            .frame(width: geo.size.width, height: geo.size.width)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .contentShape(RoundedRectangle(cornerRadius: 8))
                                            .onTapGesture {
                                                if isEditing {
                                                    if selectedPhotos.contains(photo) {
                                                        selectedPhotos.remove(photo)
                                                    } else {
                                                        selectedPhotos.insert(photo)
                                                    }
                                                } else {
                                                    router.navigate(
                                                        FullscreenPhotoView(
                                                            photos: project.photos.sorted(by: { $0.createdAt > $1.createdAt }),
                                                            initialIndex: index,
                                                            onDelete: { photo in
                                                                deletePhoto(photo)
                                                            }
                                                        ).environmentObject(router)
                                                    )
                                                }
                                            }
                                    }
                                    .onAppear {
                                        itemSize = geo.size
                                    }
                                    .onChange(of: itemSize) { _, newSize in
                                        itemSize = newSize
                                    }
                                    .contextMenu {
                                        Button {
                                            router.navigate(
                                                FullscreenPhotoView(
                                                    photos: project.photos.sorted(by: { $0.createdAt > $1.createdAt }),
                                                    initialIndex: index,
                                                    onDelete: { photo in
                                                        deletePhoto(photo)
                                                    }
                                                )
                                                .environmentObject(router)
                                                .navigationTransition(
                                                    .zoom(
                                                        sourceID: photo.id,
                                                        in: zoomTransition
                                                    )
                                                )
                                            )
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
                                            if #available(iOS 18.0, *) {
                                                AsyncImageView(fileName: fileName, loadFullResolution: false)
                                                    .frame(maxWidth: 325, maxHeight: 400)
                                                    .matchedTransitionSource(id: photo.id, in: zoomTransition)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            } else {
                                                AsyncImageView(fileName: fileName, loadFullResolution: false)
                                                    .frame(maxWidth: 325, maxHeight: 400)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
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
                                    Image(systemName: selectedPhotos.contains(photo) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundColor(selectedPhotos.contains(photo) ? .green : .gray)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .offset(x: 7, y: -7)
                                }
                            })
                        }
                    }
                    .padding()
                }
                .navigationTitle("\(project.name) (\(project.photos.count))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isEditing {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack(spacing: 0) {
                                    Image(systemName: "trash.fill")
                                    Text("(\(selectedPhotos.count))")
                                }
                            }
                            .foregroundColor(selectedPhotos.isEmpty ? .gray : .pink)
                            .disabled(selectedPhotos.isEmpty)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            withAnimation(.snappy) {
                                isEditing.toggle()
                            }
                        }) {
                            Label(isEditing ? "Bitti" : "Düzenle", systemImage: "pencil.circle")
                        }
                        .disabled(project.photos.isEmpty)
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        router.navigate(CreateAnimationView(project: project))
                    }) {
                        Image(systemName: "film")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .opacity(project.photos.isEmpty ? 0 : 1)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    Text("Fotoğraflar Yükleniyor...")
                        .font(.caption)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationView {
                List {
                    Button(action: {
                        showCamera = true
                        showAddSheet = false
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Kameradan Çek")
                        }
                    }
                    
                    Button(action: {
                        showImagePicker = true
                        showAddSheet = false
                    }) {
                        HStack {
                            Image(systemName: "photo.fill")
                            Text("Galeriden Seç")
                        }
                    }
                }
                .navigationTitle("Fotoğraf Ekle")
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.height(150)])
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { images, total in
                if let images = images {
                    isLoading = true
                    totalPhotos = total
                    
                    Task {
                        await processImages(images: images)
                        isLoading = false
                        progress = 0
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(project: project)
        }
        .confirmationDialog(
            "\(selectedPhotos.count) adet fotoğraf silinecek",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                for photo in selectedPhotos {
                    deletePhoto(photo)
                }
                selectedPhotos.removeAll()
                isEditing = !project.photos.isEmpty
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz")
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
    
    private func processImages(images: [UIImage]) async {
        for (index, image) in images.enumerated() {
            await MainActor.run {
                progress = Float(index + 1) / Float(totalPhotos)
            }
            
            let photo = ProjectPhoto()
            let fileName = ImageManager.shared.generateFileName(forProject: project.id)
            
            if ImageManager.shared.saveImage(image, withFileName: fileName) {
                await MainActor.run {
                    photo.fileName = fileName
                    photo.project = project
                    project.photos.append(photo)
                    project.lastPhotoDate = Date()
                    modelContext.insert(photo)
                }
            }
        }
        
        do {
            try await MainActor.run {
                try modelContext.save()
                if project.notificationsEnabled && project.trackingFrequency != .flexible {
                    NotificationManager.shared.scheduleNotification(for: project)
                }
            }
        } catch {
            print("Fotoğraflar kaydedilirken hata oluştu: \(error)")
        }
    }
}
