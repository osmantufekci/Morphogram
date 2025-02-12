//
//  AsyncImageView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftUI

struct AsyncImageView: View {
    let fileName: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .onAppear {
            ImageManager.shared.loadImageAsync(fileName: fileName) { loadedImage in
                self.image = loadedImage
            }
        }
    }
}
