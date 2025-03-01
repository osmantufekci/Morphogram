import AVFoundation
import UIKit
import SwiftUI

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var error: CameraError?
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var currentPosition: AVCaptureDevice.Position = .back
    private var isConfigured = false
    private var currentDevice: AVCaptureDevice?
    
    private var photoCompletion: ((Result<UIImage, Error>) -> Void)?
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case photoCaptureFailed
        case flashUnavailable
        
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
            case .flashUnavailable:
                return "Flash kullanılamıyor"
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        guard let device = currentDevice,
              device.hasFlash,
              device.isFlashAvailable else {
            error = .flashUnavailable
            return
        }
        
        do {
            try device.lockForConfiguration()
            if device.isFlashModeSupported(mode) {
                device.flashMode = mode
            }
            device.unlockForConfiguration()
        } catch {
            print("Flash modu ayarlanamadı: \(error.localizedDescription)")
        }
    }
    
    func setupCamera() {
        guard !isConfigured else { return }
        
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            error = .cameraUnavailable
            session.commitConfiguration()
            return
        }
        
        currentDevice = device
        
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
        
        if let device = currentDevice, device.hasFlash {
            settings.flashMode = device.flashMode
        }
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        // Mevcut kamera girişini kaldır
        session.inputs.forEach { input in
            session.removeInput(input)
        }
        
        // Yeni kamera pozisyonunu belirle
        currentPosition = currentPosition == .back ? .front : .back
        
        // Yeni kamera cihazını al
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
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
        
        session.commitConfiguration()
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCompletion?(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            photoCompletion?(.failure(CameraError.photoCaptureFailed))
            return
        }
        
        // Ön kamera için aynalama düzeltmesi
        if currentPosition == .front,
           let cgImage = image.cgImage {
            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
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
    @Binding var sliderValue: Double
    
    var body: some View {
        if let image {
            ZStack {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .opacity(min(max(sliderValue, 0.2), 0.6))
            }
        }
    }
} 
