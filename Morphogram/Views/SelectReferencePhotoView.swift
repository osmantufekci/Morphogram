//
//  SelectReferencePhotoView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftUI

struct SelectReferencePhotoView: View {
    let project: Project
    let onPhotoSelected: (ProjectPhoto?) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(project.photos) { photo in
                    Button(action: {
                        onPhotoSelected(photo)
                        dismiss()
                    }) {
                        HStack {
                            if let fileName = photo.fileName {
                                AsyncImageView(fileName: fileName)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .frame(width: 60, height: 60)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(formatDate(photo.createdAt))
                                    .font(.headline)
                                Text("Referans olarak kullan")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        onPhotoSelected(nil)
                        dismiss()
                    }) {
                        VStack(alignment: .leading) {
                            Text("Kullanma")
                                .font(.headline)
                                .tint(.red)
                        }
                    }
                }
            }
            .navigationTitle("Referans Fotoğraf Seç")
            .navigationBarItems(leading: Button("İptal") {
                dismiss()
            })
        }
    }
}
