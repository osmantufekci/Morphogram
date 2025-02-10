import SwiftUI
import SwiftData
import PhotosUI

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    
    private let maxLength = 25
    
    private var remainingCharacters: Int {
        maxLength - categoryName.count
    }
    
    private var isValidName: Bool {
        !categoryName.isEmpty && categoryName.count <= maxLength
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Kategori Adı", text: $categoryName)
                        .onChange(of: categoryName) { _, newValue in
                            if newValue.count > maxLength {
                                categoryName = String(newValue.prefix(maxLength))
                            }
                        }
                    
                    HStack {
                        Text("Kalan karakter:")
                            .foregroundColor(.gray)
                        Text("\(remainingCharacters)")
                            .foregroundColor(remainingCharacters < 5 ? .red : .gray)
                    }
                    .font(.caption)
                } footer: {
                    Text("Kategori adı en fazla \(maxLength) karakter olabilir")
                        .font(.caption)
                }
            }
            .navigationTitle("Yeni Kategori")
            .navigationBarItems(
                leading: Button("İptal") {
                    dismiss()
                },
                trailing: Button("Kaydet") {
                    let category = Category(name: categoryName.trimmingCharacters(in: .whitespaces))
                    modelContext.insert(category)
                    dismiss()
                }
                .disabled(!isValidName)
            )
        }
    }
}

struct AddProjectView: View {
    let category: Category
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var projectName = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Proje Adı", text: $projectName)
                
                Section {
                    Text("Kategori: \(category.name)")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Yeni Proje")
            .navigationBarItems(
                leading: Button("İptal") {
                    dismiss()
                },
                trailing: Button("Kaydet") {
                    let project = Project(name: projectName, category: category)
                    modelContext.insert(project)
                    category.projects.insert(project, at: 0)
                    dismiss()
                }
                .disabled(projectName.isEmpty)
            )
        }
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
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(project.name)
                        .font(.headline)
                    Text(project.categoryName)
                        .font(.subheadline)
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
    @Query private var categories: [Category]
    
    @State private var selectedCategory: Category?
    @State private var selectedPhoto: ProjectPhoto?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingSourceSelection = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Kategori Seçimi") {
                    ForEach(categories) { category in
                        Button(action: {
                            selectedCategory = category
                            selectedPhoto = nil
                        }) {
                            HStack {
                                Text(category.name)
                                Spacer()
                                if category.projects.first?.photos.isEmpty ?? true {
                                    Text("İlk fotoğraf")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("\(category.projects.first?.photos.count ?? 0) fotoğraf")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                
                Section("Kaynak Seçimi") {
                    Button(action: {
                        if let category = selectedCategory {
                            if category.projects.first?.photos.isEmpty ?? true {
                                showingCamera = true
                            } else {
                                showingSourceSelection = true
                            }
                        }
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
                .disabled(selectedCategory == nil)
                .opacity(selectedCategory == nil ? 0.3 : 1)
            }
            .navigationTitle("Fotoğraf Ekle")
            .navigationBarItems(leading: Button("İptal") {
                dismiss()
            })
            .sheet(isPresented: $showingSourceSelection) {
                if let category = selectedCategory {
                    SelectReferencePhotoView(category: category) { photo in
                        selectedPhoto = photo
                        showingCamera = true
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                if let category = selectedCategory {
                    ImagePicker { image in
                        if let image = image {
                            savePhoto(image: image, category: category)
                        }
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(referencePhoto: $selectedPhoto) { newImage in
                    if let category = selectedCategory {
                        savePhoto(image: newImage, category: category)
                    }
                    dismiss()
                }
            }
        }
    }
    
    
    
    private func savePhoto(image: UIImage, category: Category) {
        print("Fotoğraf kaydetme işlemi başlatıldı")
        let photo = ProjectPhoto()
        
        if let existingProject = category.projects.first {
            print("Mevcut proje bulundu: \(existingProject.name)")
            let fileName = ImageManager.shared.generateFileName(forProject: existingProject.id)
            
            if ImageManager.shared.saveImage(image, withFileName: fileName) {
                photo.fileName = fileName
                photo.project = existingProject
                existingProject.photos.append(photo)
                existingProject.lastPhotoDate = Date()
                modelContext.insert(photo)
                do {
                    try modelContext.save()
                    print("Fotoğraf ve proje güncelleme başarıyla kaydedildi")
                } catch {
                    print("Proje güncellenirken hata oluştu: \(error)")
                }
            }
        } else {
            print("Yeni proje oluşturuluyor: \(category.name)")
            let project = Project(name: category.name, category: category)
            let fileName = ImageManager.shared.generateFileName(forProject: project.id)
            
            if ImageManager.shared.saveImage(image, withFileName: fileName) {
                photo.fileName = fileName
                photo.project = project
                project.photos.append(photo)
                
                modelContext.insert(project)
                category.projects.append(project)
                
                do {
                    try modelContext.save()
                    print("Yeni proje ve fotoğraf başarıyla kaydedildi")
                } catch {
                    print("Yeni proje kaydedilirken hata oluştu: \(error)")
                }
            }
        }
        
        if let fileName = photo.fileName {
            let exists = ImageManager.shared.verifyImageExists(fileName: fileName)
            print("Fotoğraf doğrulama: \(exists ? "Başarılı" : "Başarısız")")
        }
    }
}

struct SelectReferencePhotoView: View {
    let category: Category
    let onPhotoSelected: (ProjectPhoto) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if let project = category.projects.first {
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
