import AVFoundation
import UIKit
import SwiftUI

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var error: CameraError?
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    private var isConfigured = false
    
    private var photoCompletion: ((Result<UIImage, Error>) -> Void)?
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case photoCaptureFailed
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Kamera kullanılamıyor"
            case .cannotAddInput:
                return "Kamera girişi eklenemedi"
            case .cannotAddOutput:
                return "Kamera çıkışı eklenemedi"
            case .photoCaptureFailed:
                return "Fotoğraf çekilemedi"
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    func setupCamera() {
        guard !isConfigured else { return }
        
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            error = .cameraUnavailable
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                error = .cannotAddInput
                session.commitConfiguration()
                return
            }
        } catch {
            self.error = .cannotAddInput
            session.commitConfiguration()
            return
        }
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            error = .cannotAddOutput
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        isConfigured = true
    }
    
    func start() {
        guard !session.isRunning else { return }
        
        setupCamera()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stop() {
        guard session.isRunning else { return }
        
        session.stopRunning()
    }
    
    func takePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCompletion?(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCompletion?(.failure(CameraError.photoCaptureFailed))
            return
        }
        
        photoCompletion?(.success(image))
    }
}

class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        DispatchQueue.main.async {
            uiView.previewLayer.frame = uiView.bounds
        }
    }
}

struct ReferencePhotoOverlay: View {
    let image: UIImage?
    @State private var sliderValue: Double = 0.4
    
    var body: some View {
        if let image {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(min(max(sliderValue, 0.2), 0.6))
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Slider(value: $sliderValue, in: 0...1)
                            .frame(width: 100)
                            .tint(.white)
                            .padding(.trailing, 20)
                    }
                    .padding(.bottom)
                }
            }
        }
    }
} 
