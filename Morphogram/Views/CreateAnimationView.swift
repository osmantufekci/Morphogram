import SwiftUI
import PhotosUI

enum TextPosition: String, CaseIterable {
    case none, top, bottom
    
    var image: Image {
        switch self {
        case .top:
            Image(systemName: "square.grid.3x3.topmiddle.filled")
        case .bottom:
            Image(systemName: "square.grid.3x3.bottommiddle.filled")
        case .none:
            Image(systemName: "x.square")
        }
    }
    
    
    var alignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .none: return .leading //kullanılmayacak
        }
    }
}

enum WatermarkPosition: String, CaseIterable {
    case topLeft = "Sol Üst"
    case bottomRight = "Sağ Alt"
    case center = "Orta"
    case bottomLeft = "Sol Alt"
    case topRight = "Sağ Üst"
    
    var image: Image {
        switch self {
        case .topRight:
            Image(systemName: "square.grid.3x3.topright.filled")
        case .bottomRight:
            Image(systemName: "square.grid.3x3.bottomright.filled")
        case .center:
            Image(systemName: "square.grid.3x3.middle.filled")
        case .topLeft:
            Image(systemName: "square.grid.3x3.topleft.filled")
        case .bottomLeft:
            Image(systemName: "square.grid.3x3.bottomleft.filled")
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
    @AppStorage("hasPro") var freemium: Bool = true
    
    let project: Project
    let frameDelayConstant = 1.1
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingAnimation = false
    @State private var animationType: AnimationType = .video
    @State private var frameRate: Double = 5
    @State private var frameDelay: Double = 0.5
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSharingError = false
    @State private var currentPreviewIndex = 0
    @State private var previewTimer: Timer?
    @State private var selectedPhotos: Array<String> = []
    @State private var watermarkPosition: WatermarkPosition = .center
    @State private var textPosition: TextPosition = .bottom
    @State private var progress: Float = 0
    @State private var loopCount: Int = 0
    @State private var sortedPhotos: [ProjectPhoto] = []
    @State private var resolution: Resolution = .k1080p
    @State private var useText: Bool = true
    @State private var currentPreviewImage: UIImage = UIImage()
    @State private var currentProjetPhoto: ProjectPhoto?
    @State private var fontSize: CustomFontSize = .small
    
    private var animationDuration: Double {
        let photoCount = Double(selectedPhotos.count)
        return animationType == .video ? (photoCount / frameRate) * Double(max(1, loopCount)) : (photoCount * (frameDelayConstant - frameDelay)) * Double(max(1, loopCount))
    }
    
    enum AnimationType: String, CaseIterable {
        case video = "Video"
        case gif = "GIF"
    }
    
    var body: some View {
        List {
            Section("Önizleme") {
                ZStack {
                    Image(uiImage: currentPreviewImage)
                        .resizable()
                        .frame(maxWidth: .infinity)
                        .frame(height: 400)
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .if(freemium) { view in
                            view.watermark(position: watermarkPosition, size: resolution.size)
                        }
                        .if(useText && currentProjetPhoto?.createdAt != nil) { view in
                            view.datemark(
                                position: textPosition,
                                text: currentProjetPhoto!.createdAt.formatted(date: .numeric, time: .omitted),
                                size: resolution.size,
                                fontSize: fontSize
                            )
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if animationType != .gif {
                        HStack {
                            Image(systemName: "clock")
                            Text(String(format: "Süre: %.1f saniye", animationDuration))
                        }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Önizleme ile son çıktı arasında farklar olabilir.")
                    }
                }
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
                        Slider(value: $frameRate, in: 1...10, step: 1) { _ in
                            startPreview()
                        }
                        Text("Hızlı")
                    }
                } else {
                    HStack {
                        Text("Yavaş")
                        Slider(value: $frameDelay, in: 0.1...1.0, step: 0.1) { _ in
                            startPreview()
                        }
                        Text("Hızlı")
                    }
                }
                
                if animationType == .gif {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Videoya göre daha yüksek dosya boyutu")
                        
                        if selectedPhotos.count >= 100, resolution == .k4K {
                            Text("Paylaşım veya Kaydetme başarısız olabilir.")
                        }
                    }
                    .padding(.top, 4)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
            .disabled(isCreatingAnimation)
            
            Section("Çözünürlük") {
                Picker("Çözünürlük", selection: $resolution) {
                    ForEach(Resolution.allCases, id: \.self) { resolution in
                        Text(resolution.title)
                    }
                }
                .pickerStyle(.segmented)
            }
            .disabled(isCreatingAnimation)
            
            Section("Tekrar Sayısı") {
                Picker("Tekrar", selection: $loopCount) {
                    if AnimationType.gif == animationType {
                        Text("Sonsuz").tag(0)
                    }
                    ForEach(1...5, id: \.self) { count in
                        Text("\(count) kez").tag(count)
                    }
                }
            }
            .disabled(isCreatingAnimation)
            
            Section("Tarihi Göster") {
                Picker("Tarih", selection: $textPosition) {
                    ForEach(TextPosition.allCases, id: \.self) { position in
                        position.image
                            .foregroundColor(.red)
                            .tag(position)
                    }
                }
                .pickerStyle(.segmented)
                if textPosition != .none {
                    Picker("Font", selection: $fontSize) {
                        ForEach(CustomFontSize.allCases, id: \.self) { size in
                            size.icon
                                .tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
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
            
            
            Section("") {
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
                        VStack(alignment: .center) {
                            Text("\(animationType.rawValue) Oluştur")
                                .frame(maxWidth: .infinity)
                            if selectedPhotos.count < 2 {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("En az 2 fotoğraf gereklidir")
                                }
                                .padding(.top, 4)
                                .font(.footnote)
                                .foregroundColor(.pink)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(selectedPhotos.count < 2)
                
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
            .bold()
            .disabled(isCreatingAnimation)
            
            Section("Kullanılan Fotoğraflar (\(selectedPhotos.count))") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(sortedPhotos.indices, id: \.self) { index in
                            if let fileName = sortedPhotos[index].fileName {
                                ZStack(alignment: .topTrailing) {
                                    AsyncImageView(fileName: fileName, loadFullResolution: false)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture {
                                            if selectedPhotos.contains(fileName) {
                                                selectedPhotos.removeAll(where: {$0 == fileName})
                                            } else {
                                                selectedPhotos.safeInsert(fileName, at: index)
                                            }
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
        .listSectionSpacing(8)
        .navigationTitle("Animasyon Oluştur")
        .navigationBarTitleDisplayMode(.automatic)
        .alert("Hata", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Bilinmeyen bir hata oluştu")
        }
        .alert("Hata", isPresented: $showingSharingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Paylaşılırken bir hata meydana geldi")
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [CustomActivityItemSource(url: url, projectName: project.name)], onError: { message in
                    errorMessage = message
                    showingSharingError.toggle()
                })
            }
        }
        .task {
            sortedPhotos = project.photos.sorted { $0.createdAt > $1.createdAt }
            selectedPhotos = sortedPhotos.compactMap { $0.fileName }
            startPreview()
        }
        .onChange(of: animationType) { _, _ in
            startPreview()
        }
        .onChange(of: resolution) { oldValue, newValue in
            if oldValue != newValue {
                ImageManager.shared.setResolution(newValue)
            }
        }
    }
}

extension CreateAnimationView {
    private func startPreview() {
        stopPreview()
        
        let interval = animationType == .video ? 1.0 / frameRate : (frameDelayConstant - frameDelay)
        previewTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                guard !selectedPhotos.isEmpty else { return }
                currentPreviewIndex = (currentPreviewIndex + 1) % selectedPhotos.count
                currentPreviewImage = ImageManager.shared.loadImage(fileName: selectedPhotos[currentPreviewIndex]) ?? .init()
                currentProjetPhoto = sortedPhotos.first(where: {$0.fileName == selectedPhotos[currentPreviewIndex]})
            }
        }
    }
    
    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
    }
    
    private func createAnimation() async {
        guard !sortedPhotos.isEmpty else { return }
        
        isCreatingAnimation = true
        progress = 0
        
        if animationType == .video {
            AnimationManager.shared.createVideo(
                from: sortedPhotos.filter({selectedPhotos.contains($0.fileName ?? "")}),
                frameRate: Float(frameRate),
                name: project.name,
                resolution: resolution,
                watermarkPosition: watermarkPosition,
                textPosition: textPosition,
                maxLoopCount: loopCount,
                useText: textPosition != .none,
                onProgress: { newProgress in
                    progress = newProgress
                }
            ) { url in
                handleExportResult(url)
            }
        } else {
            AnimationManager.shared.createGIF(
                from: sortedPhotos.filter({selectedPhotos.contains($0.fileName ?? "")}),
                frameDelay: frameDelayConstant - frameDelay,
                name: project.name,
                resolution: resolution,
                watermarkPosition: watermarkPosition,
                textPosition: textPosition,
                maxLoopCount: loopCount,
                useText: textPosition != .none,
                onProgress: { newProgress in
                    progress = newProgress
                }
            ) { url in
                handleExportResult(url)
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



