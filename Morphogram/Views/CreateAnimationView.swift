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

struct CreateAnimationView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingAnimation = false
    @State private var animationType: AnimationType = .video
    @State private var frameRate: Double = 7.5
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
    @State private var progress: Float = 0
    
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
                    .animation(.default, value: currentPreviewIndex)
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
                        Slider(value: $frameRate, in: 5...10, step: 0.5) { _ in
                            startPreview()
                        }
                        Text("Hızlı")
                    }
                } else {
                    HStack {
                        Text("Hızlı")
                        Slider(value: $frameDelay, in: 0.1...1.5, step: 0.3) { _ in
                            startPreview()
                        }
                        Text("Yavaş")
                    }
                }
            }
            .disabled(isCreatingAnimation)
            
            Section {
                Button(action: {
                    Task {
                        await createAnimation()
                    }
                }) {
                    if isCreatingAnimation {
                        HStack(spacing: 8) {
                            Text("%\(Int(progress * 100))")
                                .font(.caption)
                            ProgressView(value: progress * 100, total: 100.0)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("\(animationType.rawValue) Oluştur")
                    }
                }

                if animationType == .gif, !isCreatingAnimation {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Dosya boyutu daha büyük olacaktır.")
                    }
                    .padding(.top, 4)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                
                if isCreatingAnimation {
                    HStack {
                        Image(systemName: "info.circle")
                        Text((animationType == .gif ? "GIF" : "Video") + " oluşturulurken lütfen bekleyin ve uygulamayı kapatmayın.")
                    }
                    .padding(.top, 4)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
            .disabled(isCreatingAnimation)
            
            Section("Filigran Konumu") {
                Picker("Konum", selection: $watermarkPosition) {
                    ForEach(WatermarkPosition.allCases, id: \.self) { position in
                        position.image.tag(position)
                    }
                }
                .pickerStyle(.segmented)
            }
            .disabled(isCreatingAnimation)
            
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
            .disabled(isCreatingAnimation)
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
        .task {
            selectedPhotos = Set(sortedPhotos.compactMap { $0.fileName })
            loadPreviewImages()
        }
        .onChange(of: animationType) { _, _ in
            startPreview()
        }
        .onChange(of: previewImages) { oldValue, newValue in
            if newValue != oldValue {
                startPreview()
            }
        }
    }
}

extension CreateAnimationView {
    private func loadPreviewImages() {
        DispatchQueue.global(qos: .userInitiated).async {
            previewImages = sortedPhotos.compactMap { photo -> UIImage? in
                guard let fileName = photo.fileName else { return nil }
                guard selectedPhotos.isEmpty || selectedPhotos.contains(fileName) else { return nil }
                return ImageManager.shared.loadImage(fileName: fileName, downSample: true)
            }
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
    
    private func createAnimation() async {
        guard !previewImages.isEmpty else { return }
        
        isCreatingAnimation = true
        progress = 0
        
        let images = await withTaskGroup(of: UIImage?.self) { group in
            var loadedImages: [UIImage] = []
            
            for photo in sortedPhotos {
                group.addTask {
                    guard let fileName = photo.fileName,
                          await self.selectedPhotos.contains(fileName) else { return nil }
                    return ImageManager.shared.loadImage(fileName: fileName, downSample: true)
                }
            }
            
            for await image in group {
                if let image = image {
                    loadedImages.append(image)
                }
            }
            
            return loadedImages
        }
        
        await MainActor.run {
            if images.isEmpty {
                handleExportResult(nil)
                return
            }
            
            if animationType == .video {
                AnimationManager.shared.createVideo(
                    from: images,
                    frameRate: Float(frameRate),
                    name: project.name,
                    watermarkPosition: watermarkPosition,
                    onProgress: { newProgress in
                        progress = newProgress
                    }
                ) { url in
                    handleExportResult(url)
                }
            } else {
                AnimationManager.shared.createGIF(
                    from: images,
                    frameDelay: frameDelay,
                    name: project.name,
                    watermarkPosition: watermarkPosition,
                    onProgress: { newProgress in
                        progress = newProgress
                    }
                ) { url in
                    handleExportResult(url)
                }
            }
        }
    }
    
    private func handleExportResult(_ url: URL?) {
        progress = 0
        
        if let url = url {
            exportURL = url
            showingExportSheet = true
        } else {
            errorMessage = "Animasyon oluşturulamadı"
            showingError = true
        }
        
        isCreatingAnimation = false
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
