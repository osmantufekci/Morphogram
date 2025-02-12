//
//  FullscreenPhotoView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftUI

struct FullscreenPhotoView: View {
    let photos: [ProjectPhoto]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    
    var onDelete: ((ProjectPhoto) -> Void)?
    
    init(photos: [ProjectPhoto], initialIndex: Int, isPresented: Binding<Bool>, onDelete: ((ProjectPhoto) -> Void)? = nil) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack {
            PhotoPageViewController(
                photos: photos,
                currentIndex: $currentIndex
            )
            .background(Color.black)
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            if let _ = photos[currentIndex].fileName {
                                showShareSheet = true
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                Text("\(currentIndex + 1) / \(photos.count)")
                    .foregroundColor(.white)
                    .padding(.bottom)
            }
        }
        .confirmationDialog("Bu fotoğrafı silmek istediğinizden emin misiniz?",
                          isPresented: $showDeleteConfirmation,
                          titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                if currentIndex < photos.count {
                    onDelete?(photos[currentIndex])
                    if photos.count == 1 {
                        isPresented = false
                    }
                }
            }
            Button("İptal", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileName = photos[currentIndex].fileName,
               let image = UIImage(contentsOfFile: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName).path) {
                ShareSheet(activityItems: [image])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
