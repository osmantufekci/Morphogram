//
//  CameraView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//


import SwiftUI
import SwiftData

struct CameraView: View {
    let project: Project
    
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    @State private var showingReferencePhotoSelection = false
    @State private var selectedReferencePhoto: ProjectPhoto?
    
    init(project: Project) {
        self.project = project
        _selectedReferencePhoto = State(initialValue: project.photos.sorted(by: { $0.createdAt > $1.createdAt }).first)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showingPreview, let image = capturedImage {
                // Fotoğraf önizleme ekranı
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: .infinity)
                    
                    HStack(spacing: 50) {
                        Button(action: {
                            // Fotoğrafı reddet ve kameraya geri dön
                            showingPreview = false
                            capturedImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            // Fotoğrafı kaydet
                            if let finalImage = capturedImage {
                                savePhoto(image: finalImage)
                                dismiss()
                            }
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .background(Color.black)
            } else {
                // Kamera önizleme ve kontroller
                VStack(spacing: 0) {
                    ZStack {
                        // Kamera önizleme
                        CameraPreview(session: cameraManager.session)
                        
                        if let referencePhoto = selectedReferencePhoto,
                           let fileName = referencePhoto.fileName,
                           let image = ImageManager.shared.loadImage(fileName: fileName) {
                            ReferencePhotoOverlay(image: image)
                        }
                        
                        // Üst kontroller
                        VStack {
                            HStack {
                                Button(action: {
                                    dismiss()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            
                            Spacer()
                        }
                    }
                    
                    // Alt kamera kontrolleri
                    HStack(spacing: 20) {
                        Button(action: {
                            showingReferencePhotoSelection = true
                        }) {
                            Image(systemName: selectedReferencePhoto == nil ? "photo.stack" : "photo.stack.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .opacity(project.photos.isEmpty ? 0 : 1)
                        .disabled(project.photos.isEmpty ? true : false)

                        Button(action: {
                            cameraManager.takePhoto { result in
                                switch result {
                                case .success(let image):
                                    capturedImage = image
                                    showingPreview = true
                                case .failure(let error):
                                    errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 54))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        
                        Button(action: {
                            cameraManager.switchCamera()
                        }) {
                            Image(systemName: "camera.rotate.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 65)
                    .background(.black)
                    .padding(.horizontal)
                }
            }
        }
        .background(.black)
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .sheet(isPresented: $showingReferencePhotoSelection) {
            SelectReferencePhotoView(project: project) { photo in
                selectedReferencePhoto = photo
            }
        }
        .alert("Hata", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func savePhoto(image: UIImage) {
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
