//
//  ProjectPhoto.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//

import SwiftData
import Foundation

@Model
class ProjectPhoto {
    var id: String
    var fileName: String?
    var createdAt: Date
    var project: Project?
    
    init(fileName: String? = nil) {
        self.id = UUID().uuidString
        self.fileName = fileName
        self.createdAt = Date()
    }
} 
