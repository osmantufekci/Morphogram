import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound]
            return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        } catch {
            print("Bildirim izni alınamadı: \(error.localizedDescription)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    func scheduleNotification(for project: Project) {
        // Önce varolan bildirimleri temizle
        cancelNotifications(for: project)
        
        // Bildirimler kapalıysa veya esnek takip ise bildirim oluşturma
        guard project.notificationsEnabled, project.trackingFrequency != .flexible else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Fotoğraf Zamanı!"
        content.body = "\(project.name) projesi için yeni bir fotoğraf ekleme zamanı geldi."
        content.sound = .default
        
        // Bir sonraki fotoğraf zamanını hesapla
        let nextPhotoDate = calculateNextPhotoDate(for: project)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextPhotoDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "project-\(project.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Bildirim planlanırken hata oluştu: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotifications(for project: Project) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["project-\(project.id)"])
    }
    
    private func calculateNextPhotoDate(for project: Project) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let days = project.trackingFrequency.days
        
        // Son fotoğraf tarihinden days kadar sonrasını hesapla
        if let nextDate = calendar.date(byAdding: .day, value: days, to: project.lastPhotoDate) {
            // Eğer hesaplanan tarih geçmişte kalıyorsa, şu andan days kadar sonrasını al
            return nextDate > now ? nextDate : calendar.date(byAdding: .day, value: days, to: now) ?? now
        }
        
        return now
    }
} 