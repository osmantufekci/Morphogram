//
//  Project.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//

import SwiftData
import Foundation

@Model
final class Project {
    enum TrackingFrequency: Codable, Equatable, Hashable, CaseIterable {
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
        
        static var allCases: [TrackingFrequency] {
            [.daily, .weekly, .monthly, .flexible]
        }
    }
    
    var id: String
    var name: String
    var createdAt: Date
    var lastPhotoDate: Date
    var photos: [ProjectPhoto]
    var trackingFrequency: TrackingFrequency
    var notificationsEnabled: Bool
    var calendarEnabled: Bool
    var guideType: GuideType?
    var eventIdentifier: String? = nil
    
    init(name: String, trackingFrequency: TrackingFrequency = .flexible, notificationsEnabled: Bool = true, calendarEnabled: Bool = false, guideType: GuideType? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.lastPhotoDate = Date()
        self.photos = []
        self.trackingFrequency = trackingFrequency
        self.notificationsEnabled = notificationsEnabled
        self.calendarEnabled = calendarEnabled
        self.guideType = guideType
    }
}
