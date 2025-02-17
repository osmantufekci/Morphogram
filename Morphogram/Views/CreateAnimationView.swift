import SwiftUI
import PhotosUI

struct CreateAnimationView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingAnimation = false
    @State private var animationType: AnimationType = .video
    @State private var frameRate: Double = 10.0
    @State private var frameDelay: Double = 0.5
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var currentPreviewIndex = 0
    @State private var previewTimer: Timer?
    @State private var previewImages: [UIImage] = []
    
    private var sortedPhotos: [ProjectPhoto] {
        project.photos.sorted { $0.createdAt < $1.createdAt }
    }
    
    enum AnimationType: String, CaseIterable {
        case video = "Video"
        case gif = "GIF"
    }
    
    var body: some View {
        List {
            Section("Önizleme") {
                if !previewImages.isEmpty {
                    ZStack {
                        ForEach(previewImages.indices, id: \.self) { index in
                            Image(uiImage: previewImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 450)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .opacity(index == currentPreviewIndex ? 1 : 0)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentPreviewIndex)
                    .listRowInsets(EdgeInsets())
                } else {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(height: 300)
                }
            }
            
            Section("Animasyon Türü") {
                Picker("Tür", selection: $animationType) {
                    ForEach(AnimationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                if animationType == .video {
                    HStack {
                        Text("FPS")
                        Slider(value: $frameRate, in: 10...15, step: 0.5) { _ in
                            startPreview()
                        }
                        Text(String(format: "%.1f", frameRate))
                    }
                } else {
                    HStack {
                        Text("Kare Gecikmesi")
                        Slider(value: $frameDelay, in: 0.1...2.0, step: 0.1) { _ in
                            startPreview()
                        }
                        Text(String(format: "%.1f s", frameDelay))
                    }
                }
            }
            
            Section {
                Button(action: createAnimation) {
                    if isCreatingAnimation {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("\(animationType.rawValue) Oluştur")
                    }
                }
                .disabled(isCreatingAnimation)
            }
            
            Section("Fotoğraflar (\(sortedPhotos.count))") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(sortedPhotos) { photo in
                            if let fileName = photo.fileName {
                                AsyncImageView(fileName: fileName)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .frame(height: 100)
            }
        }
        .navigationTitle("Animasyon Oluştur")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("İptal") {
                    stopPreview()
                    dismiss()
                }
            }
        }
        
        .alert("Hata", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Bilinmeyen bir hata oluştu")
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [CustomActivityItemSource(url: url, projectName: project.name)])
            }
        }
        .onAppear {
            loadPreviewImages()
        }
        .onChange(of: animationType) { _, _ in
            startPreview()
        }
    }
    
    private func loadPreviewImages() {
        previewImages = sortedPhotos.compactMap { photo -> UIImage? in
            guard let fileName = photo.fileName else { return nil }
            return ImageManager.shared.loadImage(fileName: fileName)
        }
        
        if !previewImages.isEmpty {
            startPreview()
        }
    }
    
    private func startPreview() {
        guard !previewImages.isEmpty else { return }
        
        stopPreview()
        
        let interval = animationType == .video ? 1.0 / frameRate : frameDelay
        
        previewTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation {
                    currentPreviewIndex = (currentPreviewIndex + 1) % previewImages.count
                }
            }
        }
        
        RunLoop.current.add(previewTimer!, forMode: .common)
    }
    
    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
    }
    
    private func createAnimation() {
        guard !sortedPhotos.isEmpty else { return }
        
        isCreatingAnimation = true
        stopPreview()
        
        if animationType == .video {
            AnimationManager.shared.createVideo(from: previewImages, frameRate: Float(frameRate), name: project.name) { url in
                handleExportResult(url)
            }
        } else {
            AnimationManager.shared.createGIF(from: previewImages, frameDelay: frameDelay) { url in
                handleExportResult(url)
            }
        }
    }
    
    private func handleExportResult(_ url: URL?) {
        DispatchQueue.main.async {
            isCreatingAnimation = false
            startPreview()
            
            if let url = url {
                exportURL = url
                showingExportSheet = true
            } else {
                errorMessage = "Animasyon oluşturulamadı"
                showingError = true
            }
        }
    }
}

// ActivityItemSource sınıfını ekleyelim
class CustomActivityItemSource: NSObject, UIActivityItemSource {
    let url: URL
    let projectName: String
    
    init(url: URL, projectName: String) {
        self.url = url
        self.projectName = projectName
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return projectName
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return url.pathExtension == "gif" ? "com.compuserve.gif" : "public.mpeg-4"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
