//
//  CameraView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//


import SwiftUI
import SwiftData
import AVFoundation

enum FlashMode {
    case auto
    case on
    case off
    
    var systemImageName: String {
        switch self {
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        }
    }
    
    var captureFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .auto: return .auto
        case .on: return .on
        case .off: return .off
        }
    }
}

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
    @State private var selectedGuide: GuideType = .none
    @State private var flashMode: FlashMode = .auto
    
    init(project: Project) {
        self.project = project
        _selectedReferencePhoto = State(initialValue: project.photos.sorted(by: { $0.createdAt > $1.createdAt }).first)
        _selectedGuide =  State(initialValue: project.guideType ?? .none)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showingPreview, let image = capturedImage {
                // Fotoğraf önizleme ekranı
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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
                    .frame(maxHeight: 65)
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
                        
                        GuideOverlay(guideType: selectedGuide)
                        
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
                        Menu {
                            Button("3x3") {
                                selectedGuide = .grid3x3
                            }
                            Button("5x5") {
                                selectedGuide = .grid5x5
                            }
                            Button("Oval") {
                                selectedGuide = .oval
                            }
                            Button("None") {
                                selectedGuide = .none
                            }
                        } label: {
                            Image(systemName: selectedGuide == .none ? "grid.circle" : "grid.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        
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
                            switch flashMode {
                            case .auto:
                                flashMode = .on
                            case .on:
                                flashMode = .off
                            case .off:
                                flashMode = .auto
                            }
                        }) {
                            Image(systemName: flashMode.systemImageName)
                                .font(.system(size: 20))
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
        .onChange(of: flashMode) { _, newValue in
            cameraManager.setFlashMode(newValue.captureFlashMode)
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
            project.guideType = selectedGuide
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
