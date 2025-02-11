//
//  CameraView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//


import SwiftUI
import SwiftData

struct CameraView: View {
    @Binding var referencePhoto: ProjectPhoto?
    let onPhotoTaken: (UIImage) -> Void
    
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var capturedImage: UIImage?
    @State private var showingPreview = false
    
    var body: some View {
        ZStack {
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
                            // Fotoğrafı kabul et
                            if let finalImage = capturedImage {
                                onPhotoTaken(finalImage)
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
                // Kamera önizleme
                CameraPreview(session: cameraManager.session)
                
                if let referencePhoto = referencePhoto,
                   let fileName = referencePhoto.fileName,
                   let image = ImageManager.shared.loadImage(fileName: fileName) {
                    ReferencePhotoOverlay(image: image)
                }
                
                // Kontroller
                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
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
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .padding(.bottom, 25)
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .alert("Hata", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}