import Foundation
import UIKit
import AVFoundation
import ImageIO

class AnimationManager {
    static let shared = AnimationManager()
    
    private init() {}
    
    // Video oluşturma fonksiyonu
    func createVideo(from images: [UIImage], frameRate: Float = 2.0, name: String, completion: @escaping (URL?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).mp4")
        let settings = RenderSettings(
            size: images[0].size,
            fps: frameRate,
            avCodecKey: AVVideoCodecType.h264,
            videoFilepath: outputURL.path
        )
        
        guard let videoWriter = try? VideoWriter(settings: settings) else {
            completion(nil)
            return
        }
        
        videoWriter.start()
        
        var frameCount: Int64 = 0
        
        for image in images {
            let frameDuration = CMTime(value: frameCount, timescale: CMTimeScale(frameRate))
            videoWriter.addImage(image: image, withPresentationTime: frameDuration)
            frameCount += 1
        }
        
        videoWriter.finish { success in
            completion(success ? outputURL : nil)
        }
    }
    
    // GIF oluşturma fonksiyonu
    func createGIF(from images: [UIImage], frameDelay: Double = 0.5, loopCount: Int = 0, completion: @escaping (URL?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gif")
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, images.count, nil) else {
            completion(nil)
            return
        }
        
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFDelayTime as String: frameDelay
        ]]
        
        let gifProperties = [kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFLoopCount as String: loopCount
        ]]
        
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        for image in images {
            if let cgImage = image.cgImage {
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }
        }
        
        if CGImageDestinationFinalize(destination) {
            completion(outputURL)
        } else {
            completion(nil)
        }
    }
}

// Video oluşturma için yardımcı sınıflar
private struct RenderSettings {
    var size: CGSize
    var fps: Float
    var avCodecKey: AVVideoCodecType
    var videoFilepath: String
    
    var videoSettings: [String: Any] {
        [
            AVVideoCodecKey: avCodecKey,
            AVVideoWidthKey: size.height,
            AVVideoHeightKey: size.width
        ]
    }
}

private class VideoWriter {
    private var assetWriter: AVAssetWriter
    private var assetWriterInput: AVAssetWriterInput
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    init(settings: RenderSettings) throws {
        assetWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: settings.videoFilepath), fileType: .mp4)
        
        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings.videoSettings)
        assetWriterInput.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: settings.size.height,
            kCVPixelBufferHeightKey as String: settings.size.width
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        assetWriter.add(assetWriterInput)
    }
    
    func start() {
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
    }
    
    func addImage(image: UIImage, withPresentationTime time: CMTime) {
        guard let pixelBuffer = image.pixelBuffer(size: image.size) else { return }
        
        while !assetWriterInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: time)
    }
    
    func finish(completion: @escaping (Bool) -> Void) {
        assetWriterInput.markAsFinished()
        assetWriter.finishWriting {
            completion(self.assetWriter.status == .completed)
        }
    }
}

// UIImage uzantısı
private extension UIImage {
    func pixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(size.width),
                                       Int(size.height),
                                       kCVPixelFormatType_32ARGB,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.draw(self.cgImage!, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
} 
