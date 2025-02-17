import SwiftUI
import PhotosUI

enum WatermarkPosition: String, CaseIterable {
    case topLeft = "Sol Üst"
    case bottomRight = "Sağ Alt"
    case center = "Orta"
    case bottomLeft = "Sol Alt"
    case topRight = "Sağ Üst"
    
    var image: Image {
        switch self {
        case .topRight:
            Image(systemName: "arrow.up.right")
        case .bottomRight:
            Image(systemName: "arrow.down.right")
        case .center:
            Image(systemName: "square.grid.3x3.middle.filled")
        case .topLeft:
            Image(systemName: "arrow.up.left")
        case .bottomLeft:
            Image(systemName: "arrow.down.left")
        }
    }
    
    var alignment: Alignment {
        switch self {
        case .center: return .center
        case .topRight: return .topTrailing
        case .bottomRight: return .bottomTrailing
        case .topLeft: return .topLeading
        case .bottomLeft: return .bottomLeading
        }
    }
}

struct WatermarkOverlay: View {
    let position: WatermarkPosition
    
    var body: some View {
        Text("Morphogram")
            .font(.system(size: 35, weight: .bold))
            .foregroundColor(.white)
            .opacity(0.10)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    }
}

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
    @State private var selectedPhotos: Set<String> = []
    @State private var watermarkPosition: WatermarkPosition = .center
    
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
                        
                        WatermarkOverlay(position: watermarkPosition)
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
                
                HStack {
                    Image(systemName: "info.circle")
                    Text("Önizleme ile son çıktı arasında kalite farkı olabilir.")
                }
                .padding(.top, 4)
                .font(.footnote)
                .foregroundColor(.secondary)
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
                        Text("Yavaş")
                        Slider(value: $frameRate, in: 10...15, step: 0.5) { _ in
                            startPreview()
                        }
                        Text("Hızlı")
                    }
                } else {
                    HStack {
                        Text("Erken")
                        Slider(value: $frameDelay, in: 0.1...2.0, step: 0.1) { _ in
                            startPreview()
                        }
                        Text("Geç")
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
                if animationType == .gif {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Dosya boyutu daha büyük olacaktır.")
                    }
                    .padding(.top, 4)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
            
            Section("Filigran Konumu") {
                Picker("Konum", selection: $watermarkPosition) {
                    ForEach(WatermarkPosition.allCases, id: \.self) { position in
                        position.image.tag(position)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Kullanılan Fotoğraflar (\(selectedPhotos.count))") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(sortedPhotos) { photo in
                            if let fileName = photo.fileName {
                                ZStack(alignment: .topTrailing) {
                                    AsyncImageView(fileName: fileName)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture {
                                            if selectedPhotos.contains(fileName) {
                                                selectedPhotos.remove(fileName)
                                            } else {
                                                selectedPhotos.insert(fileName)
                                            }
                                            loadPreviewImages()
                                        }
                                    
                                    if selectedPhotos.contains(fileName) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .background(Circle().fill(Color.white))
                                            .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .frame(height: 100)
            }
        }
        .navigationTitle("Animasyon Oluştur")
        .navigationBarTitleDisplayMode(.automatic)
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
            // Tüm fotoğrafları seçili olarak işaretle
            selectedPhotos = Set(sortedPhotos.compactMap { $0.fileName })
            loadPreviewImages()
        }
        .onChange(of: animationType) { _, _ in
            startPreview()
        }
    }
    
    private func loadPreviewImages() {
        previewImages = sortedPhotos.compactMap { photo -> UIImage? in
            guard let fileName = photo.fileName else { return nil }
            guard selectedPhotos.isEmpty || selectedPhotos.contains(fileName) else { return nil }
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
        guard !previewImages.isEmpty else { return }
        
        isCreatingAnimation = true
        
        let images = sortedPhotos.compactMap { photo -> UIImage? in
            guard let fileName = photo.fileName,
                  selectedPhotos.contains(fileName),
                  let image = ImageManager.shared.loadImage(fileName: fileName) else { return nil }
            return image
        }
        
        if animationType == .video {
            AnimationManager.shared.createVideo(
                from: images,
                frameRate: Float(frameRate),
                name: project.name,
                watermarkPosition: watermarkPosition
            ) { url in
                handleExportResult(url)
            }
        } else {
            AnimationManager.shared.createGIF(
                from: images,
                frameDelay: frameDelay,
                name: project.name,
                watermarkPosition: watermarkPosition
            ) { url in
                handleExportResult(url)
            }
        }
    }
    
    private func handleExportResult(_ url: URL?) {
        isCreatingAnimation = false
        
        if let url = url {
            exportURL = url
            showingExportSheet = true
        } else {
            errorMessage = "Animasyon oluşturulamadı"
            showingError = true
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
