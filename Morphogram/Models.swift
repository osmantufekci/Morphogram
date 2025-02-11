import Foundation
import SwiftData

@Model
class Category {
    var id: String
    var name: String
    var projects: [Project]
    
    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.projects = []
    }
}

@Model
class Project {
    var id: String
    var name: String
    var createdAt: Date
    var lastPhotoDate: Date
    var photos: [ProjectPhoto]
    
    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.lastPhotoDate = Date()
        self.photos = []
    }
}

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
