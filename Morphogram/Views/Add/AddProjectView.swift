//
//  AddProjectView.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//


import SwiftUI
import SwiftData

struct AddProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var projectName: String
    @State private var selectedFrequency: Project.TrackingFrequency
    @State private var customDays: String = ""
    @State private var showingCustomDaysInput = false
    @State private var notificationsEnabled: Bool
    @State private var showingNotificationAlert = false
    @State private var hasNotificationPermission = false
    @State private var calendarEnabled = false
    @State private var calendarStartDate = Date()
    
    private let existingProject: Project?
    
    init(project: Project? = nil) {
        self.existingProject = project
        _projectName = State(initialValue: project?.name ?? "w")
        _selectedFrequency = State(initialValue: project?.trackingFrequency ?? .daily)
        _notificationsEnabled = State(initialValue: project?.notificationsEnabled ?? false)
        _calendarEnabled = State(initialValue: project?.calendarEnabled ?? false)
        if case .custom(let days) = project?.trackingFrequency {
            _customDays = State(initialValue: "\(days)")
            _showingCustomDaysInput = State(initialValue: true)
        }
    }
    
    private var isCustomDaysValid: Bool {
        if let days = Int(customDays) {
            return days > 0 && days <= 365
        }
        return false
    }
    
    var body: some View {
        Form {
            Section("Proje Bilgileri") {
                TextField("Proje Adı", text: $projectName)
            }
            
            Section("Takip Sıklığı") {
                Picker("Takip Sıklığı", selection: $selectedFrequency) {
                    Text("Günlük").tag(Project.TrackingFrequency.daily)
                    Text("Haftalık").tag(Project.TrackingFrequency.weekly)
                    Text("Aylık").tag(Project.TrackingFrequency.monthly)
                    Text("Esnek").tag(Project.TrackingFrequency.flexible)
                    Text("Özel").tag(Project.TrackingFrequency.custom(days: max(1, Int(customDays) ?? 1)))
                }
                .onChange(of: selectedFrequency) { _, newValue in
                    if case .custom = newValue {
                        showingCustomDaysInput = true
                    } else {
                        showingCustomDaysInput = false
                    }
                }
                
                if showingCustomDaysInput {
                    HStack {
                        TextField("Gün sayısı", text: $customDays)
                            .keyboardType(.numberPad)
                        Text("günde bir")
                    }
                    
                    if !isCustomDaysValid {
                        Text("Lütfen 1-365 arası bir sayı girin")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                HStack {
                    Image(systemName: "info.circle")
                    switch selectedFrequency {
                    case .daily:
                        Text("Her gün yeni bir fotoğraf eklemeniz beklenir.")
                    case .weekly:
                        Text("Haftada bir fotoğraf eklemeniz beklenir.")
                    case .monthly:
                        Text("Ayda bir fotoğraf eklemeniz beklenir.")
                    case .flexible:
                        Text("İstediğiniz zaman fotoğraf ekleyebilirsiniz.")
                    case .custom:
                        Text("\(customDays) günde bir fotoğraf eklemeniz beklenir.")
                    }
                }
                .padding(.top, 4)
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("Hatırlatıcı Bildirimler", isOn: $notificationsEnabled)
                    .opacity(selectedFrequency != .flexible ? 1 : 0.5)
                    .disabled(selectedFrequency == .flexible)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }
            } footer: {
                if selectedFrequency == .flexible {
                    Text("Esnek projelerde bildirim almazsınız.")
                        .foregroundColor(.orange)
                } else if hasNotificationPermission {
                    Text("Fotoğraf ekleme zamanı geldiğinde bildirim alırsınız.")
                } else {
                    Text("Bildirimleri kullanabilmek için izin vermeniz gerekiyor.")
                        .foregroundColor(.orange)
                }
            }
            .onChange(of: selectedFrequency) { _, newValue in
                if newValue == .flexible {
                    notificationsEnabled = false
                    calendarEnabled = false
                }
            }
            
            Section {
                Toggle("Takvime Ekle", isOn: $calendarEnabled)
                    .opacity(selectedFrequency != .flexible ? 1 : 0.5)
                    .disabled(selectedFrequency == .flexible)
                    .padding(.vertical, 2)
                
                if calendarEnabled && selectedFrequency != .flexible {
                    DatePicker(
                        "Başlangıç Tarihi",
                        selection: $calendarStartDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .padding(.vertical, 2)
                }
            } footer: {
                if selectedFrequency == .flexible {
                    Text("Esnek projelerde takvim etkinliği oluşturulmaz.")
                        .foregroundColor(.orange)
                } else {
                    Text("Fotoğraf çekme zamanları takviminize eklenecek.")
                }
            }
        }
        .navigationTitle(existingProject == nil ? "Yeni Proje" : "Ayarlar")
        
        .navigationBarItems(
            trailing: HStack {
                Button(existingProject == nil ? "Kaydet" : "Güncelle") {
                    saveProject()
                }
            }
                .disabled(projectName.isEmpty || (showingCustomDaysInput && !isCustomDaysValid))
        )
        .alert("Bildirim İzni", isPresented: $showingNotificationAlert) {
            Button("Ayarlar'a Git") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("İptal", role: .cancel) {
                notificationsEnabled = false
            }
        } message: {
            Text("Bildirimleri kullanabilmek için Ayarlar'dan uygulama bildirimlerini etkinleştirmeniz gerekiyor.")
        }
        .task {
            hasNotificationPermission = await NotificationManager.shared.checkAuthorizationStatus()
        }
        
    }
    
    private func requestNotificationPermission() {
        Task {
            let authorized = await NotificationManager.shared.requestAuthorization()
            await MainActor.run {
                if authorized {
                    hasNotificationPermission = true
                } else {
                    notificationsEnabled = false
                    showingNotificationAlert = true
                }
            }
        }
    }
    
    private func saveProject() {
        var frequency = selectedFrequency
        if case .custom = selectedFrequency, let days = Int(customDays) {
            frequency = .custom(days: days)
        }
        
        if let project = existingProject {
            // Mevcut projeyi güncelle
            project.name = projectName.trimmingCharacters(in: .whitespaces)
            project.trackingFrequency = frequency
            project.notificationsEnabled = notificationsEnabled && hasNotificationPermission
            project.calendarEnabled = calendarEnabled
            
            // Bildirimleri güncelle
            if project.notificationsEnabled {
                NotificationManager.shared.scheduleNotification(for: project)
            } else {
                NotificationManager.shared.cancelNotifications(for: project)
            }
            
            // Takvim etkinliğini güncelle
            if project.calendarEnabled {
                Task {
                    if await CalendarManager.shared.addRecurringEventToCalendar(
                        project: project,
                        title: "📸 \(project.name) - Fotoğraf Çekimi",
                        startDate: calendarStartDate,
                        frequency: project.trackingFrequency,
                        notes: "Morphogram uygulaması tarafından oluşturuldu"
                    ) {
                        try? modelContext.save()
                    }
                }
            } else {
                Task {
                    await CalendarManager.shared.removeAllEvents(forProject: project)
                }
            }
        } else {
            // Yeni proje oluştur
            let project = Project(
                name: projectName.trimmingCharacters(in: .whitespaces),
                trackingFrequency: frequency,
                notificationsEnabled: notificationsEnabled && hasNotificationPermission,
                calendarEnabled: calendarEnabled
            )
            modelContext.insert(project)
            
            // Bildirimleri ayarla
            if project.notificationsEnabled {
                NotificationManager.shared.scheduleNotification(for: project)
            }
            
            // Takvim etkinliğini oluştur
            if project.calendarEnabled {
                Task {
                    if await CalendarManager.shared.addRecurringEventToCalendar(
                        project: project,
                        title: "📸 \(project.name) - Fotoğraf Çekimi",
                        startDate: calendarStartDate,
                        frequency: project.trackingFrequency,
                        notes: "Morphogram uygulaması tarafından oluşturuldu"
                    ) {
                        try? modelContext.save()
                    }
                }
            }
        }
        
        dismiss()
    }
}
