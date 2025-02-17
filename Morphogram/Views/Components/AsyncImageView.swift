//
//  AsyncImageView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftUI

struct AsyncImageView: View {
    let fileName: String
    @State private var image: Image?
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .task {
            ImageManager.shared.loadImageAsync(fileName: fileName) { loadedImage in
                self.image = Image(uiImage: loadedImage)
            }
        }
    }
}
