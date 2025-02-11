import SwiftUI

struct AddEventView: View {
    @State private var eventTitle = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 saat sonrası
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isRecurring = false
    @State private var selectedFrequency = Project.TrackingFrequency.daily
    @State private var customDays = 3
    @Environment(\.dismiss) private var dismiss
    
    private var isCustomDaysValid: Bool {
        return customDays > 0 && customDays <= 365
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Etkinlik Detayları")) {
                    TextField("Etkinlik Başlığı", text: $eventTitle)
                    DatePicker("Başlangıç", selection: $startDate)
                    DatePicker("Bitiş", selection: $endDate)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section(header: Text("Tekrar")) {
                    Toggle("Tekrarlı Etkinlik", isOn: $isRecurring)
                    
                    if isRecurring {
                        HStack {
                            Text("Tekrar Sıklığı")
                            Spacer()
                            Menu {
                                Button("Günlük") {
                                    selectedFrequency = .daily
                                }
                                Button("Haftalık") {
                                    selectedFrequency = .weekly
                                }
                                Button("Aylık") {
                                    selectedFrequency = .monthly
                                }
                                Button("Özel") {
                                    selectedFrequency = .custom(days: customDays)
                                }
                            } label: {
                                Text(selectedFrequency.description)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if case .custom = selectedFrequency {
                            Stepper(
                                "\(customDays) günde bir",
                                value: $customDays,
                                in: 1...365,
                                step: 1
                            )
                            .onChange(of: customDays) { _, newValue in
                                selectedFrequency = .custom(days: newValue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yeni Etkinlik")
            .navigationBarItems(
                leading: Button("İptal") {
                    dismiss()
                },
                trailing: Button("Kaydet") {
                    saveEvent()
                }
                .disabled(eventTitle.isEmpty)
            )
        }
        .alert("Etkinlik Durumu", isPresented: $showingAlert) {
            Button("Tamam") {
                if alertMessage.contains("başarıyla") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveEvent() {
        guard !eventTitle.isEmpty else {
            alertMessage = "Lütfen etkinlik başlığı giriniz"
            showingAlert = true
            return
        }
        
        if isRecurring {
            Task {
                let success = await CalendarManager.shared.addRecurringEventToCalendar(
                    title: eventTitle,
                    startDate: startDate,
                    frequency: selectedFrequency,
                    notes: notes.isEmpty ? nil : notes
                )
                
                alertMessage = success ? "Tekrarlı etkinlik başarıyla eklendi" : "Etkinlik eklenirken bir hata oluştu"
                showingAlert = true
            }
        } else {
            Task {
                let success = await CalendarManager.shared.addRecurringEventToCalendar(
                    title: eventTitle,
                    startDate: startDate,
                    frequency: .flexible, // Tekrarsız etkinlik için flexible kullanıyoruz
                    notes: notes.isEmpty ? nil : notes
                )
                
                alertMessage = success ? "Etkinlik başarıyla eklendi" : "Etkinlik eklenirken bir hata oluştu"
                showingAlert = true
            }
        }
    }
} 
