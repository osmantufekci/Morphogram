import Foundation
import Photos
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
    func createVideo(
        from images: [String],
        frameRate: Float = 2.0,
        name: String,
        resolution outputSize: Resolution,
        onProgress: ((Float) -> Void)? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let documentDirectory = urls.first else {
            fatalError("documentDir Error")
        }
        
        let videoOutputURL = documentDirectory.appendingPathComponent("\(name).mp4")

        if FileManager.default.fileExists(atPath: videoOutputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: videoOutputURL.path)
            } catch {
                fatalError("Unable to delete file: \(error) : \(#function).")
            }
        }
        
        guard let videoWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mp4) else {
            fatalError("AVAssetWriter error")
        }
        
        let outputSettings = [
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : NSNumber(value: Float(outputSize.size.width)),
            AVVideoHeightKey : NSNumber(value: Float(outputSize.size.height))
        ] as [String : Any]
        
        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) else {
            fatalError("Negative : Can't apply the Output settings...")
        }
        
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let sourcePixelBufferAttributesDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputSize.size.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputSize.size.height))
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        var chosenImages = images
        if videoWriter.startWriting() {
            videoWriter.startSession(atSourceTime: CMTime.zero)
            assert(pixelBufferAdaptor.pixelBufferPool != nil)
            
            let media_queue = DispatchQueue(__label: "mediaInputQueue", attr: nil)
            
            videoWriterInput.requestMediaDataWhenReady(on: media_queue, using: { () -> Void in
                let fps: Int32 = Int32(frameRate)
                let frameDuration = CMTimeMake(value: 1, timescale: fps)
                
                var frameCount: Int64 = 0
                var appendSucceeded = true
                
                while (!chosenImages.isEmpty) {
                    if (videoWriterInput.isReadyForMoreMediaData) {
                        guard let nextPhoto = ImageManager.shared.loadImage(fileName: chosenImages.remove(at: 0)) else { continue}
                        let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                        
                        var pixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                        
                        if let pixelBuffer = pixelBuffer, status == 0 {
                            let managedPixelBuffer = pixelBuffer
                            
                            CVPixelBufferLockBaseAddress(managedPixelBuffer, [])
                            
                            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                            let context = CGContext(data: data, width: Int(outputSize.size.width), height: Int(outputSize.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                            
                            context?.clear(CGRect(x: 0, y: 0, width: outputSize.size.width, height: outputSize.size.height))
                            
                            let horizontalRatio = CGFloat(outputSize.size.width) / nextPhoto.size.width
                            let verticalRatio = CGFloat(outputSize.size.height) / nextPhoto.size.height
                            
                            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
                            
                            let newSize = CGSize(width: nextPhoto.size.width * aspectRatio, height: nextPhoto.size.height * aspectRatio)
                            
                            let x = newSize.width < outputSize.size.width ? (outputSize.size.width - newSize.width) / 2 : 0
                            let y = newSize.height < outputSize.size.height ? (outputSize.size.height - newSize.height) / 2 : 0
                            
                            context?.draw(nextPhoto.cgImage!, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
                            
                            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, [])
                            
                            appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        } else {
                            print("Failed to allocate pixel buffer")
                            appendSucceeded = false
                        }
                    }
                    if !appendSucceeded {
                        break
                    }
                    frameCount += 1
                    onProgress?(Float(frameCount) / Float(images.count))
                }
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting { () -> Void in
                    print("FINISHED!!!!!")
                    completion(videoOutputURL)
                }
            })
        }
    }
    
    // GIF oluşturma fonksiyonu
    func createGIF(
        from images: [UIImage],
        frameDelay: Double = 0.5,
        name: String,
        watermarkPosition: WatermarkPosition = .center,
        loopCount: Int = 0,
        onProgress: ((Float) -> Void)? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard !images.isEmpty else {
                completion(nil)
                return
            }
            
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).gif")
            
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, images.count, nil) else {
                completion(nil)
                return
            }
            
            // GIF ayarlarını optimize et
            let frameProperties = [kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyColorModel as String: kCGImagePropertyColorModelRGB,
                kCGImagePropertyDepth as String: 8,
                kCGImagePropertyHasAlpha as String: true
            ]]
            
            let gifProperties = [kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount,
                kCGImagePropertyGIFHasGlobalColorMap as String: true,
                kCGImagePropertyColorModel as String: kCGImagePropertyColorModelRGB,
                kCGImagePropertyDepth as String: 8
            ]]
            
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
            
            // İlk görüntüyü al ve boyutlarını optimize et
            let firstImage = images[0]
            let maxSize: CGFloat = 1024 // Maksimum boyut
            let scale = min(maxSize / firstImage.size.width, maxSize / firstImage.size.height, 1.0)
            let targetSize = CGSize(
                width: firstImage.size.width * scale,
                height: firstImage.size.height * scale
            )
            
            // Watermark layer'ı bir kere oluştur
            let watermarkLayer = self.createWatermarkLayer(size: targetSize, position: watermarkPosition)
            let padding: CGFloat = targetSize.width * 0.05
            let textSize = watermarkLayer.frame.size
            
            // Render context'i bir kere oluştur
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            
            // Batch işleme için değişkenler
            let batchSize = min(15, images.count)
            let totalBatches = Int(ceil(Double(images.count) / Double(batchSize)))
            let totalImages = Float(images.count)
            let processedImagesCount = Atomic<Float>(0)
            
            // Her batch'i sırayla işle
            for batchIndex in 0..<totalBatches {
                autoreleasepool {
                    let start = batchIndex * batchSize
                    let end = min(start + batchSize, images.count)
                    let currentBatch = Array(images[start..<end])
                    
                    // Batch'teki görüntüleri işle
                    let group = DispatchGroup()
                    var processedFrames: [(CGImage, Int)] = []
                    
                    // Batch'teki her görüntüyü paralel işle
                    for (index, image) in currentBatch.enumerated() {
                        group.enter()
                        
                        autoreleasepool {
                            // Görüntüyü yeniden boyutlandır
                            let resizedImage = image.resize(to: targetSize)
                            
                            let watermarkedImage = renderer.image { context in
                                // Orijinal görüntüyü çiz
                                resizedImage.draw(in: CGRect(origin: .zero, size: targetSize))
                                
                                // Context'i kaydet
                                context.cgContext.saveGState()
                                
                                var transform = CGAffineTransform.identity
                                // Pozisyona göre transform uygula
                                switch watermarkPosition {
                                case .center:
                                    transform = transform.translatedBy(x: targetSize.width/2, y: targetSize.height/2)
                                    transform = transform.rotated(by: .pi/4)
                                    transform = transform.translatedBy(x: -textSize.width/2, y: -textSize.height/2)
                                case .topRight:
                                    transform = transform.translatedBy(x: targetSize.width - padding - textSize.width, y: padding)
                                case .bottomRight:
                                    transform = transform.translatedBy(x: targetSize.width - padding - textSize.width, y: targetSize.height - padding - textSize.height)
                                case .topLeft:
                                    transform = transform.translatedBy(x: padding, y: padding)
                                case .bottomLeft:
                                    transform = transform.translatedBy(x: padding, y: targetSize.height - padding - textSize.height)
                                }
                                context.cgContext.concatenate(transform)
                                
                                // Watermark'ı çiz
                                watermarkLayer.render(in: context.cgContext)
                                
                                // Context'i geri yükle
                                context.cgContext.restoreGState()
                            }
                            
                            if let cgImage = watermarkedImage.cgImage {
                                processedFrames.append((cgImage, index))
                                let newCount = processedImagesCount.increment(by: 1)
                                
                                // Her görsel işlendiğinde ilerlemeyi güncelle
                                DispatchQueue.main.async {
                                    onProgress?(newCount / totalImages)
                                }
                            }
                            
                            group.leave()
                        }
                    }
                    
                    // Batch'teki tüm frame'ler işlenince
                    group.wait()
                    
                    // Frame'leri sıralı şekilde GIF'e ekle
                    processedFrames.sorted { $0.1 < $1.1 }.forEach { image, _ in
                        CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
                    }
                    
                    // Batch işlemi bitti, belleği temizle
                    processedFrames.removeAll()
                }
            }
            
            // Son ilerlemeyi bildir
            DispatchQueue.main.async {
                onProgress?(1.0)
            }
            
            let success = CGImageDestinationFinalize(destination)
            
            DispatchQueue.main.async {
                completion(success ? outputURL : nil)
            }
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

// Görüntü boyutlandırma için extension
extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaledImage = renderer.image { context in
            self.draw(in: CGRect(origin: .zero, size: targetSize), blendMode: .normal, alpha: 1.0) // Tam boyut için
        }
        
        return scaledImage
    }
}

final class Atomic<T: Numeric> {
    private var value: T
    private let queue = DispatchQueue(label: "com.morphogram.atomic")
    
    init(_ value: T) {
        self.value = value
    }
    
    func increment(by amount: T) -> T {
        queue.sync {
            value += amount
            return value
        }
    }
}


