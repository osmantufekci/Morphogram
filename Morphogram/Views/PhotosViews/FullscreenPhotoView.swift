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
    @State private var showSettings = false
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
            
            // Ayarlar menüsü
            if showSettings {
                ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            Button(action: {
                                // Flip işlemi burada yapılacak
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                                        .font(.title2)
                                    Text("Yatay Çevir")
                                        .font(.caption)
                                }
                            }
                            
                            Button(action: {
                                // Döndürme işlemi burada yapılacak
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "rotate.right")
                                        .font(.title2)
                                    Text("Döndür")
                                        .font(.caption)
                                }
                            }
                            
                            Button(action: {
                                // Filtreler...
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.filters")
                                        .font(.title2)
                                    Text("Filtreler")
                                        .font(.caption)
                                }
                            }
                            
                            Button(action: {
                                // Kırpma işlemi burada yapılacak
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "crop")
                                        .font(.title2)
                                    Text("Kırp")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.horizontal)
                    
                }
                .frame(height: 70)
                .transition(.opacity)
                .tint(.white)
            }
            
            // Alt kontrol alanı
            VStack(spacing: 15) {
                HStack {
                    
//                    Button(action: {
//                        withAnimation {
//                            showSettings.toggle()
//                        }
//                    }) {
//                        VStack(spacing: 5) {
//                            Image(systemName: "slider.horizontal.3")
//                                .font(.title2)
//                                .foregroundColor(showSettings ? .primary : .blue)
//                        }
//                    }
                    
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
            
            ToolbarItem(placement: .topBarTrailing) {
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
            if let project = photos[currentIndex].project, let fileName = photos[currentIndex].fileName {
                ShareSheet(
                    activityItems: [CustomActivityItemSource(
                        url: FileManager.default.urls(
                            for: .documentDirectory,
                            in: .userDomainMask
                        ).first!.appendingPathComponent(fileName),
                        projectName: project.name
                    )]
                )
            }
        }
    }
}
