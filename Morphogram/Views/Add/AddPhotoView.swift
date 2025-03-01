//
//  AddPhotoView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftUI
import SwiftData

struct AddPhotoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Project.lastPhotoDate) private var allProjects: [Project]
    @State private var selectedProject: Project?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isLoading = false
    @State private var progress: Float = 0
    @State private var totalPhotos: Int = 0
    
    var body: some View {
        ZStack {
            List {
                Section("Proje Seçimi") {
                    ForEach(allProjects) { project in
                        Button(action: {
                            selectedProject = project
                        }) {
                            HStack {
                                Text(project.name)
                                if project == selectedProject {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Text("Son: " + formatDate(project.lastPhotoDate))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                if selectedProject != nil {
                    Section("Kaynak Seçimi") {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Kameradan Çek")
                            }
                        }
                        
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.fill")
                                Text("Galeriden Seç")
                            }
                        }
                    }
                }
            }
            .disabled(isLoading)
            
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
        .navigationTitle("Fotoğraf Ekle")
        .sheet(isPresented: $showingImagePicker) {
            if let project = selectedProject {
                ImagePicker { images, total in
                    if let images = images {
                        isLoading = true
                        totalPhotos = total
                        
                        Task {
                            await processImages(images: images, project: project)
                            isLoading = false
                            progress = 0
                            dismiss()
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            if let project = selectedProject {
                CameraView(project: project)
            }
        }
    }
    
    private func processImages(images: [UIImage], project: Project) async {
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
