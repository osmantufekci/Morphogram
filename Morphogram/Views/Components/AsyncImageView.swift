//
//  AsyncImageView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftUI

struct AsyncImageView: View {
    let fileName: String
    var loadFullResolution: Bool = false
    
    @State private var thumbnailImage: Image?
    @State private var fullResImage: Image?
    @State private var isLoadingFullRes = false
    
    var body: some View {
        Group {
            if let image = (loadFullResolution ? fullResImage : thumbnailImage) ?? thumbnailImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .task {
            // Önce thumbnail'ı yükle
            if thumbnailImage == nil {
                ImageManager.shared.loadImageAsync(fileName: fileName, thumbnail: true) { loadedImage in
                    self.thumbnailImage = Image(uiImage: loadedImage)
                }
            }
            
            // Eğer tam çözünürlük isteniyorsa, onu da yükle
            if loadFullResolution && fullResImage == nil && !isLoadingFullRes {
                isLoadingFullRes = true
                ImageManager.shared.loadImageAsync(fileName: fileName, thumbnail: false) { loadedImage in
                    self.fullResImage = Image(uiImage: loadedImage)
                    self.isLoadingFullRes = false
                }
            }
        }
    }
}
