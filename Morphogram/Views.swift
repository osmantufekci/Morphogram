import SwiftUI
import SwiftData
import PhotosUI

struct AddProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var projectName = ""
    
    var body: some View {
        NavigationView {
            Form {
                
                Section {
                    TextField("Proje Adı", text: $projectName)
                }
            }
            .navigationTitle("Yeni Proje")
            .navigationBarItems(
                leading: Button("İptal") {
                    dismiss()
                },
                trailing: Button("Kaydet") {
                    let project = Project(name: projectName)
                    modelContext.insert(project)
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
                        .foregroundColor(.black)
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
