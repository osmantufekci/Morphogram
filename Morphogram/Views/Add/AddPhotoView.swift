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
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("Fotoğraf Ekle")
            .navigationBarItems(leading: Button("İptal") {
                dismiss()
            })
            .sheet(isPresented: $showingImagePicker) {
                if let project = selectedProject {
                    ImagePicker { image in
                        if let image = image {
                            savePhoto(image: image, project: project)
                        }
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                if let project = selectedProject {
                    CameraView(project: project)
                }
            }
        }
    }
    
    private func savePhoto(image: UIImage, project: Project) {
        let photo = ProjectPhoto()
        let fileName = ImageManager.shared.generateFileName(forProject: project.id)
        
        if ImageManager.shared.saveImage(image, withFileName: fileName) {
            photo.fileName = fileName
            photo.project = project
            project.photos.append(photo)
            project.lastPhotoDate = Date()
            modelContext.insert(photo)
            
            do {
                try modelContext.save()
                print("Fotoğraf başarıyla kaydedildi")
                
                // Bir sonraki bildirimi planla
                if project.notificationsEnabled && project.trackingFrequency != .flexible {
                    NotificationManager.shared.scheduleNotification(for: project)
                }
            } catch {
                print("Fotoğraf kaydedilirken hata oluştu: \(error)")
            }
        }
    }
}
