import Foundation
import EventKit

class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestAccess(to: .event)
        } catch {
            print("Takvim erişim hatası: \(error)")
            return false
        }
    }
    
    func addRecurringEventToCalendar(
        title: String,
        startDate: Date,
        frequency: Project.TrackingFrequency,
        notes: String? = nil
    ) async -> Bool {
        let hasAccess = await requestAccess()
        guard hasAccess else { return false }
        
        // Önce eski etkinlikleri temizle
        removeExistingEvents(withTitle: title)
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(300) // 5 dakika
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Tekrar kuralını ayarla
        let recurrenceRule: EKRecurrenceRule?
        switch frequency {
        case .daily:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: nil
            )
        case .weekly:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
        case .monthly:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                end: nil
            )
        case .custom(let days):
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: days,
                end: nil
            )
        case .flexible:
            recurrenceRule = nil
        }
        
        if let rule = recurrenceRule {
            event.addRecurrenceRule(rule)
        }
        
        do {
            try eventStore.save(event, span: .futureEvents)
            return true
        } catch {
            print("Etkinlik ekleme hatası: \(error)")
            return false
        }
    }
    
    func removeAllEvents(forProject project: Project) async {
        let hasAccess = await requestAccess()
        guard hasAccess else { return }
        
        let calendar = Calendar.current
        let oneYearFromNow = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(
            withStart: Date(),
            end: oneYearFromNow,
            calendars: [eventStore.defaultCalendarForNewEvents].compactMap { $0 }
        )
        
        let existingEvents = eventStore.events(matching: predicate)
            .filter { $0.title.contains(project.name) && $0.title.contains("📸") }
        
        for event in existingEvents {
            do {
                try eventStore.remove(event, span: .futureEvents)
            } catch {
                print("Etkinlik silme hatası: \(error)")
            }
        }
    }
    
    private func removeExistingEvents(withTitle title: String) {
        let calendar = Calendar.current
        let oneYearFromNow = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(
            withStart: Date(),
            end: oneYearFromNow,
            calendars: [eventStore.defaultCalendarForNewEvents].compactMap { $0 }
        )
        
        let existingEvents = eventStore.events(matching: predicate)
            .filter { $0.title == title }
        
        for event in existingEvents {
            do {
                try eventStore.remove(event, span: .futureEvents)
            } catch {
                print("Etkinlik silme hatası: \(error)")
            }
        }
    }
} 