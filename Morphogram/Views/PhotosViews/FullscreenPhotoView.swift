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
    @State private var currentIndex: Int
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @EnvironmentObject private var router: NavigationManager
    
    var onDelete: ((ProjectPhoto) -> Void)?
    
    init(photos: [ProjectPhoto], initialIndex: Int, onDelete: ((ProjectPhoto) -> Void)? = nil) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
        self.onDelete = onDelete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Fotoğraf görüntüleyici
            PhotoPageViewController(
                photos: photos,
                currentIndex: $currentIndex
            )
            .clipShape(
                .rect(
                    bottomLeadingRadius: 15,
                    bottomTrailingRadius: 15
                )
            )
            
            // Alt kontrol alanı
            VStack(spacing: 15) {
                HStack {
                    Button(action: {
                        if let _ = photos[currentIndex].fileName {
                            showShareSheet = true
                        }
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.callout)
                    
                    Spacer()
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 4) {
                    if let project = photos[currentIndex].project {
                        Text(project.name)
                            .font(.headline)
                    }
                    Text(formatDate(photos[currentIndex].createdAt))
                        .font(.subheadline)
                }
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Bu fotoğrafı silmek istediğinizden emin misiniz?",
                          isPresented: $showDeleteConfirmation,
                          titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                if currentIndex < photos.count {
                    onDelete?(photos[currentIndex])
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
