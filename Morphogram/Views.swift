import SwiftUI
import SwiftData
import PhotosUI

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
    
    private let existingProject: Project?
    
    init(project: Project? = nil) {
        self.existingProject = project
        _projectName = State(initialValue: project?.name ?? "")
        _selectedFrequency = State(initialValue: project?.trackingFrequency ?? .daily)
        _notificationsEnabled = State(initialValue: project?.notificationsEnabled ?? false)
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
        NavigationView {
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
                        
                        if !customDays.isEmpty && !isCustomDaysValid {
                            Text("Lütfen 1-365 arası bir sayı girin")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
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
                
                
                Section("Bilgi") {
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
            }
            .navigationTitle(existingProject == nil ? "Yeni Proje" : "Proje Ayarları")
            .navigationBarItems(
                leading: Button("İptal") {
                    dismiss()
                },
                trailing: Button(existingProject == nil ? "Kaydet" : "Güncelle") {
                    saveProject()
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
            
            // Bildirimleri güncelle
            if project.notificationsEnabled {
                NotificationManager.shared.scheduleNotification(for: project)
            } else {
                NotificationManager.shared.cancelNotifications(for: project)
            }
        } else {
            // Yeni proje oluştur
            let project = Project(
                name: projectName.trimmingCharacters(in: .whitespaces),
                trackingFrequency: frequency,
                notificationsEnabled: notificationsEnabled && hasNotificationPermission
            )
            modelContext.insert(project)
            
            // Bildirimleri ayarla
            if project.notificationsEnabled {
                NotificationManager.shared.scheduleNotification(for: project)
            }
        }
        
        dismiss()
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct AsyncImageView: View {
    let fileName: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            ImageManager.shared.loadImageAsync(fileName: fileName) { loadedImage in
                self.image = loadedImage
            }
        }
    }
}

struct ProjectCard: View {
    let project: Project
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    Text(project.trackingFrequency.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(project.photos.count) fotoğraf")
                        .font(.caption)
                    Text("Son: \(formatDate(project.lastPhotoDate))")
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
        .swipeActions(edge: .trailing) {
            Button {
                showingSettings = true
            } label: {
                Label("Ayarlar", systemImage: "gear")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showingSettings) {
            AddProjectView(project: project)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct AddPhotoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Project.lastPhotoDate) private var allProjects: [Project]
    @State private var selectedProject: Project?
    @State private var selectedPhoto: ProjectPhoto?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingSourceSelection = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Proje Seçimi") {
                    ForEach(allProjects) { project in
                        Button(action: {
                            selectedProject = project
                            selectedPhoto = nil
                        }) {
                            HStack {
                                Text(project.name)
                                Spacer()
                                if project == selectedProject {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                if selectedProject != nil {
                    Section("Kaynak Seçimi") {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Kameradan Çek")
                            }
                        }
                        
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.fill")
                                Text("Galeriden Seç")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fotoğraf Ekle")
            .navigationBarItems(leading: Button("İptal") {
                dismiss()
            })
            .sheet(isPresented: $showingSourceSelection) {
                if let project = selectedProject {
                    SelectReferencePhotoView(project: project) { photo in
                        selectedPhoto = photo
                        showingCamera = true
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                if let project = selectedProject {
                    ImagePicker { image in
                        if let image = image {
                            savePhoto(image: image, project: project)
                        }
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(referencePhoto: $selectedPhoto) { newImage in
                    if let project = selectedProject {
                        savePhoto(image: newImage, project: project)
                    }
                    dismiss()
                }
            }
        }
    }
    
    private func savePhoto(image: UIImage, project: Project) {
        let photo = ProjectPhoto()
        let fileName = ImageManager.shared.generateFileName(forProject: project.id)
        
        if ImageManager.shared.saveImage(image, withFileName: fileName) {
            photo.fileName = fileName
            photo.project = project
            project.photos.append(photo)
            project.lastPhotoDate = Date()
            modelContext.insert(photo)
            
            do {
                try modelContext.save()
                print("Fotoğraf başarıyla kaydedildi")
                
                // Bir sonraki bildirimi planla
                if project.notificationsEnabled && project.trackingFrequency != .flexible {
                    NotificationManager.shared.scheduleNotification(for: project)
                }
            } catch {
                print("Fotoğraf kaydedilirken hata oluştu: \(error)")
            }
        }
    }
}

struct SelectReferencePhotoView: View {
    let project: Project
    let onPhotoSelected: (ProjectPhoto) -> Void
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
            }
            .navigationTitle("Referans Fotoğraf Seç")
            .navigationBarItems(leading: Button("İptal") {
                dismiss()
            })
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct CameraView: View {
    @Binding var referencePhoto: ProjectPhoto?
    let onPhotoTaken: (UIImage) -> Void
    
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Kamera önizleme
            CameraPreview(session: cameraManager.session)
            
            if let referencePhoto = referencePhoto,
               let fileName = referencePhoto.fileName,
               let image = ImageManager.shared.loadImage(fileName: fileName) {
                ReferencePhotoOverlay(image: image)
            }
            
            // Kontroller
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    Button(action: {
                        cameraManager.takePhoto { result in
                            switch result {
                            case .success(let image):
                                onPhotoTaken(image)
                            case .failure(let error):
                                errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    }) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 25)
                    Spacer()
                }
            }
        }
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .alert("Hata", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (UIImage?) -> Void
        
        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else {
                completion(nil)
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.completion(image as? UIImage)
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, ProjectPhoto.self, configurations: config)
    
    return Dashboard()
        .modelContainer(container)
}
