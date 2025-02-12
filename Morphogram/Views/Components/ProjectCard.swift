//
//  ProjectCard.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftData
import SwiftUI

struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        NavigationLink(destination: ProjectPhotosGridView(project: project)) {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            
                        Text(project.trackingFrequency.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(project.photos.count) fotoğraf")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("İlk: \(formatDate(project.createdAt))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if let lastPhoto = project.photos.last,
                       let fileName = lastPhoto.fileName {
                        AsyncImageView(fileName: fileName)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}
