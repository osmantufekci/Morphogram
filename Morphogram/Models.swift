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
    enum TrackingFrequency: Codable, Equatable, Hashable {
        case daily
        case weekly
        case monthly
        case flexible
        case custom(days: Int)
        
        var description: String {
            switch self {
            case .daily:
                return "Günlük"
            case .weekly:
                return "Haftalık"
            case .monthly:
                return "Aylık"
            case .flexible:
                return "Esnek"
            case .custom(let days):
                return "\(days) günde bir"
            }
        }
        
        var days: Int {
            switch self {
            case .daily:
                return 1
            case .weekly:
                return 7
            case .monthly:
                return 30
            case .flexible:
                return 0
            case .custom(let days):
                return days
            }
        }
    }
    
    var id: String
    var name: String
    var createdAt: Date
    var lastPhotoDate: Date
    var photos: [ProjectPhoto]
    var trackingFrequency: TrackingFrequency
    
    init(name: String, trackingFrequency: TrackingFrequency = .flexible) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.lastPhotoDate = Date()
        self.photos = []
        self.trackingFrequency = trackingFrequency
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
