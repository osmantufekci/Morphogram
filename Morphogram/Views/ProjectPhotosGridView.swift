//
//  ProjectPhotosGridView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//

import SwiftUI

struct ProjectPhotosGridView: View {
    let project: Project
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(project.photos.sorted(by: { $0.createdAt > $1.createdAt })) { photo in
                    if let fileName = photo.fileName {
                        AsyncImageView(fileName: fileName)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: 125, maxHeight: 125)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                Text(formatDate(photo.createdAt))
                                    .font(.caption)
                                    .padding(4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(4)
                                    .padding(4),
                                alignment: .bottom
                            )
                    }
                }
            }
            .padding(8)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
