import Foundation
import UIKit
import AVFoundation
import ImageIO

final class AnimationManager {
    static let shared = AnimationManager()
    
    private init() {}
    
    // Watermark oluşturma fonksiyonu
    private func createWatermarkLayer(size: CGSize, position: WatermarkPosition) -> CATextLayer {
        let watermarkLayer = CATextLayer()
        watermarkLayer.string = "Morphogram"
        watermarkLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 0, nil)
        watermarkLayer.fontSize = size.width * 0.1
        watermarkLayer.foregroundColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        // Metin boyutunu hesapla
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size.width * 0.1, weight: .bold)
        ]
        let textSize = ("Morphogram" as NSString).size(withAttributes: attributes)
        
        // Layer'ı sadece metin boyutunda ayarla
        watermarkLayer.frame = CGRect(origin: .zero, size: CGSize(width: textSize.width * 1.1, height: textSize.height * 1.1))
        
        return watermarkLayer
    }
    
    // Video oluşturma fonksiyonu
    func createVideo(from images: [UIImage], frameRate: Float = 2.0, name: String, watermarkPosition: WatermarkPosition = .center, completion: @escaping (URL?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        
        FileManager.default.clearTmpDirectory()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).mp4")
        
        // Video ayarlarını oluştur
        let videoSize = images[0].size
        let videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height
        ] as [String: Any]
        
        // Asset Writer'ı hazırla
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            completion(nil)
            return
        }
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = true
        
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: attributes
        )
        
        assetWriter.add(writerInput)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        
        // Watermark layer'ı oluştur
        let watermarkLayer = createWatermarkLayer(size: videoSize, position: watermarkPosition)
        
        // Frame'leri ekle
        var frameCount: Int64 = 0
        let group = DispatchGroup()
        
        for image in images {
            group.enter()
            
            let renderer = UIGraphicsImageRenderer(size: videoSize)
            let watermarkedImage = renderer.image { context in
                // Orijinal görüntüyü çiz
                image.draw(in: CGRect(origin: .zero, size: videoSize))
                
                let padding: CGFloat = videoSize.width * 0.015
                let textSize = watermarkLayer.frame.size
                
                // Context'i kaydet
                context.cgContext.saveGState()
                
                // Pozisyona göre transform uygula
                switch watermarkPosition {
                case .center:
                    // Merkeze taşı
                    context.cgContext.translateBy(x: videoSize.width/2, y: videoSize.height/2)
                    // Metin boyutunun yarısı kadar geri çek
                    context.cgContext.translateBy(x: -textSize.width/2, y: -textSize.height/2)
                    
                case .topRight:
                    context.cgContext.translateBy(x: videoSize.width - padding - textSize.width, y: padding)
                    
                case .bottomRight:
                    context.cgContext.translateBy(x: videoSize.width - padding - textSize.width, 
                                               y: videoSize.height - padding - textSize.height)
                    
                case .topLeft:
                    context.cgContext.translateBy(x: padding, y: padding)
                    
                case .bottomLeft:
                    context.cgContext.translateBy(x: padding, 
                                               y: videoSize.height - padding - textSize.height)
                }
                
                // Watermark'ı çiz
                watermarkLayer.render(in: context.cgContext)
                
                // Context'i geri yükle
                context.cgContext.restoreGState()
            }
            
            guard let buffer = watermarkedImage.pixelBuffer(size: videoSize) else {
                group.leave()
                continue
            }
            
            let frameTime = CMTimeMake(value: frameCount, timescale: CMTimeScale(frameRate))
            
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            adaptor.append(buffer, withPresentationTime: frameTime)
            frameCount += 1
            group.leave()
        }
        
        group.notify(queue: .main) {
            writerInput.markAsFinished()
            assetWriter.finishWriting {
                completion(assetWriter.status == .completed ? outputURL : nil)
            }
        }
    }
    
    // GIF oluşturma fonksiyonu
    func createGIF(from images: [UIImage], frameDelay: Double = 0.5, name: String, watermarkPosition: WatermarkPosition = .center, loopCount: Int = 0, completion: @escaping (URL?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        FileManager.default.clearTmpDirectory()
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).gif")
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
        
        // Her kareye watermark ekle
        let watermarkLayer = createWatermarkLayer(size: images[0].size, position: watermarkPosition)
        
        for image in images {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            let watermarkedImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: image.size))
                
                let padding: CGFloat = image.size.width * 0.05
                let textSize = watermarkLayer.frame.size
                
                // Context'i kaydet
                context.cgContext.saveGState()
                
                // Pozisyona göre transform uygula
                switch watermarkPosition {
                case .center:
                    // Merkeze taşı
                    context.cgContext.translateBy(x: image.size.width/2, y: image.size.height/2)
                    // 45 derece döndür
                    context.cgContext.rotate(by: .pi/4)
                    // Metin boyutunun yarısı kadar geri çek
                    context.cgContext.translateBy(x: -textSize.width/2, y: -textSize.height/2)
                    
                case .topRight:
                    context.cgContext.translateBy(x: image.size.width - padding - textSize.width, y: padding)
                    
                case .bottomRight:
                    context.cgContext.translateBy(x: image.size.width - padding - textSize.width, 
                                               y: image.size.height - padding - textSize.height)
                    
                case .topLeft:
                    context.cgContext.translateBy(x: padding, y: padding)
                    
                case .bottomLeft:
                    context.cgContext.translateBy(x: padding, 
                                               y: image.size.height - padding - textSize.height)
                }
                
                // Watermark'ı çiz
                watermarkLayer.render(in: context.cgContext)
                
                // Context'i geri yükle
                context.cgContext.restoreGState()
            }
            
            if let cgImage = watermarkedImage.cgImage {
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
struct RenderSettings {
    var size: CGSize
    var fps: Float
    var avCodecKey: AVVideoCodecType
    var videoFilepath: String
    
    var videoSettings: [String: Any] {
        [
            AVVideoCodecKey: avCodecKey,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
    }
}


