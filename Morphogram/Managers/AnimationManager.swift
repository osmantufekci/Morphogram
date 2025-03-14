import Foundation
import Photos
import UIKit
import AVFoundation
import ImageIO
import SwiftUI

final class AnimationManager {
    static let shared = AnimationManager()
    @AppStorage("hasPro") private var freemium: Bool = true
    private init() {}
    
    // Video oluşturma fonksiyonu
    func createVideo(
        from images: [ProjectPhoto],
        frameRate: Float = 2.0,
        name: String,
        resolution outputSize: Resolution,
        watermarkPosition: WatermarkPosition = .center,
        textPosition: TextPosition = .bottom,
        maxLoopCount: Int = 0,
        useText: Bool = false,
        onProgress: ((Float) -> Void)? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
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
            
            guard let videoWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: .mp4) else {
                fatalError("AVAssetWriter error")
            }
            
            let outputSettings = [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : outputSize.size.width,
                AVVideoHeightKey : outputSize.size.height
            ] as [String : Any]
            
            guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: .video) else {
                fatalError("Negative : Can't apply the Output settings...")
            }
            
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            
            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32ARGB,
                    kCVPixelBufferCGImageCompatibilityKey as String: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
                ]
            )
            
            if videoWriter.canAdd(videoWriterInput) {
                videoWriterInput.expectsMediaDataInRealTime = false
                videoWriter.add(videoWriterInput)
            }
            
            let originalImages = images
            
            let totalFrameCount = maxLoopCount <= 1 ? originalImages.count : originalImages.count * maxLoopCount
            
            if videoWriter.startWriting() {
                videoWriter.startSession(atSourceTime: CMTime.zero)
                assert(pixelBufferAdaptor.pixelBufferPool != nil)
                
                let mediaQueue = DispatchQueue(label: "mediaInputQueue")
                
                videoWriterInput.requestMediaDataWhenReady(
                    on: mediaQueue,
                    using: {
                        let fps: Int32 = Int32(frameRate)
                        let frameDuration = CMTimeMake(value: 1, timescale: fps)
                        
                        var frameCount: Int64 = 0
                        var currentLoopCount = 0
                        var appendSucceeded = true
                        
                        let targetLoopCount = maxLoopCount <= 1 ? 1 : maxLoopCount
                        let watermarkImage = UIImage(named: "watermark")
                        while currentLoopCount < targetLoopCount && appendSucceeded {
                            for image in originalImages {
                                if !videoWriterInput.isReadyForMoreMediaData {
                                    Thread.sleep(forTimeInterval: 0.1)
                                    continue
                                }
                                guard let imageName = image.fileName else { return }
                                guard let nextPhoto = ImageManager.shared.loadImage(fileName: imageName) else { continue }
                                
                                let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                                let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                                
                                var pixelBuffer: CVPixelBuffer? = nil
                                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                                
                                if let pixelBuffer = pixelBuffer,
                                   status == 0 {
                                    let managedPixelBuffer = pixelBuffer
                                    
                                    CVPixelBufferLockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                                    
                                    let context = CGContext(
                                        data: CVPixelBufferGetBaseAddress(managedPixelBuffer),
                                        width: Int(outputSize.size.width),
                                        height: Int(outputSize.size.height),
                                        bitsPerComponent: 8,
                                        bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer),
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                    )
                                    
                                    context?.clear(CGRect(x: 0, y: 0, width: outputSize.size.width, height: outputSize.size.height))
                                    
                                    if let transform = nextPhoto.getTransform(by: outputSize.size) {
                                        context?.saveGState()
                                        context?.concatenate(transform)
                                    }
                                    
                                    switch nextPhoto.imageOrientation {
                                    case .left,
                                            .leftMirrored,
                                            .right,
                                            .rightMirrored:
                                        context?.draw(nextPhoto.cgImage!, in: CGRect(x: 0, y: 0, width: outputSize.size.height, height: outputSize.size.width))
                                    default:
                                        context?.draw(nextPhoto.cgImage!, in: CGRect(x: 0, y: 0, width: outputSize.size.width, height: outputSize.size.height))
                                    }
                                    context?.restoreGState()
                                    
                                    if useText {
                                        self.drawText(in: context, size: outputSize.size, position: textPosition, text: image.createdAt.formatted(date: .numeric, time: .omitted))
                                    }
                                    
                                    if self.freemium {
                                        self.drawWatermark(
                                            in: context,
                                            size: outputSize.size,
                                            position: watermarkPosition,
                                            watermarkImage: watermarkImage
                                        )
                                    }
                                
                                CVPixelBufferUnlockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
                                
                                appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                                
                                if !appendSucceeded {
                                    print("Failed to append pixel buffer")
                                    break
                                }
                                
                                frameCount += 1
                                
                                let progress = Float(frameCount) / Float(totalFrameCount)
                                onProgress?(progress)
                            } else {
                                print("Failed to allocate pixel buffer")
                                appendSucceeded = false
                                break
                            }
                        }
                        
                        currentLoopCount += 1
                        print("Completed loop \(currentLoopCount) of \(targetLoopCount)")
                    }
                    
                    videoWriterInput.markAsFinished()
                    videoWriter.finishWriting { () -> Void in
                        completion(videoOutputURL)
                    }
                })
            }
        }
    }
    
    func createGIF(
        from images: [ProjectPhoto],
        frameDelay: Double = 0.5,
        name: String,
        resolution outputSize: Resolution,
        watermarkPosition: WatermarkPosition = .center,
        textPosition: TextPosition = .bottom,
        maxLoopCount: Int = 0,
        useText: Bool = false,
        onProgress: ((Float) -> Void)? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard !images.isEmpty else {
                completion(nil)
                return
            }
            
            let fileManager = FileManager.default
            let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            guard let documentDirectory = urls.first else {
                fatalError("documentDir Error")
            }
            
            let outputURL = documentDirectory.appendingPathComponent("\(name).gif")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                do {
                    try FileManager.default.removeItem(atPath: outputURL.path)
                } catch {
                    fatalError("Unable to delete file: \(error) : \(#function).")
                }
            }
            
            let frameProperties = [kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFLoopCount as String: maxLoopCount,
                kCGImagePropertyColorModel as String: kCGImagePropertyColorModelRGB,
                kCGImagePropertyGIFHasGlobalColorMap as String: false,
                kCGImagePropertyDepth as String: 8,
                kCGImagePropertyHasAlpha as String: false
            ]] as CFDictionary
            
            if let url = outputURL as CFURL? {
                if let destination = CGImageDestinationCreateWithURL(url, UTType.gif.identifier as CFString, images.count, nil) {
                    CGImageDestinationSetProperties(destination, frameProperties)
                    
                    let totalImages = Float(images.count)
                    var chosenImages = images
                    var frameCount = 0
                    let watermarkImage = UIImage(named: "watermark")
                    while(!chosenImages.isEmpty) {
                        let projectPhoto = chosenImages.remove(at: 0)
                        guard let fileName = projectPhoto.fileName else { return }
                        guard let image = ImageManager.shared.loadImage(fileName: fileName)?.resizeImageTo(size: outputSize.size) else { continue }
                        autoreleasepool {
                            if var cgImage = image.cgImage {
                                if let fixedImage = image.fixImageOrientation(by: outputSize.size)?.cgImage {
                                    cgImage = fixedImage
                                }
                                
                                guard let context = CGContext(data: nil,
                                                              width: Int(outputSize.size.width),
                                                              height: Int(outputSize.size.height),
                                                              bitsPerComponent: 8,
                                                              bytesPerRow: 0,
                                                              space: CGColorSpaceCreateDeviceRGB(),
                                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                                context.clear(CGRect(x: 0, y: 0, width: outputSize.size.width, height: outputSize.size.height))
                                
                                context.draw(cgImage, in: CGRect(origin: .zero, size: outputSize.size))
                                
                                if useText {
                                    self.drawText(
                                        in: context,
                                        size: outputSize.size,
                                        position: textPosition,
                                        text: projectPhoto.createdAt.formatted(date: .numeric, time: .omitted)
                                    )
                                    
                                    if let newCGImage = context.makeImage() {
                                        cgImage = newCGImage
                                    }
                                }
                                if self.freemium {
                                    self.drawWatermark(
                                        in: context,
                                        size: outputSize.size,
                                        position: watermarkPosition,
                                        watermarkImage: watermarkImage
                                    )
                                }
                                
                                if let newCGImage = context.makeImage() {
                                    cgImage = newCGImage
                                }
                                CGImageDestinationAddImage(destination, cgImage, frameProperties)
                                frameCount += 1
                                onProgress?(Float(frameCount) / totalImages)
                            }
                        }
                    }
                    
                    completion(CGImageDestinationFinalize(destination) ? outputURL : nil)
                }
            }
        }
    }
    
    private func drawText(in context: CGContext?, size: CGSize, position: TextPosition, text: String) {
        guard let context else { return }
        let padding = 80.0
        context.saveGState()
        
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 0, nil)
        textLayer.fontSize = size.width * 0.05
        textLayer.foregroundColor = UIColor.orange.withAlphaComponent(0.7).cgColor
        textLayer.alignmentMode = .center
        textLayer.isGeometryFlipped = true
        textLayer.anchorPoint = .init(x: 0.5, y: 0.5)
        
        // Metin boyutunu hesapla
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size.width * 0.05, weight: .bold)
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        
        // Layer'ı sadece metin boyutunda ayarla
        textLayer.frame = CGRect(origin: .zero, size: CGSize(width: textSize.width * 1.1, height: textSize.height * 1.1))
        
        // Pozisyona göre metin konumunu ayarla
        var textPosition: CGPoint
        switch position {
        case .none: return
        case .bottom:
            textPosition = CGPoint(x: (size.width) / 2, y: padding)
        case .top:
            textPosition = CGPoint(x: (size.width) / 2, y: size.height - padding)
        }
        
        context.translateBy(x: textPosition.x - textSize.width/2, y: textPosition.y - textSize.height/2)
        textLayer.render(in: context)
        
        context.restoreGState()
    }
    
    // Watermark ekleme için PNG kullanma metodu
    private func drawWatermark(in context: CGContext?, size: CGSize, position: WatermarkPosition, watermarkImage: UIImage?) {
        guard let context = context, let watermarkImage else { return }
        let padding = 40.0
        // Watermark boyutunu hesapla (genişliğin %30'u kadar)
        let watermarkWidth = size.width * 0.3
        let aspectRatio = watermarkImage.size.width / watermarkImage.size.height
        let watermarkHeight = watermarkWidth / aspectRatio
        
        // Pozisyona göre watermark konumunu ayarla
        var watermarkRect: CGRect
        
        // UIKit koordinat sistemi ile CGContext'in koordinat sistemi birbirinden farklı. Örnek: CGContext origin (0,0) noktası sol alt köşedir, UIKit'in sol üst. Dolayısıyla enumlar değiştirildi
        switch position {
        case .bottomLeft:
            watermarkRect = CGRect(x: padding, y: padding, width: watermarkWidth, height: watermarkHeight)
        case .bottomRight:
            watermarkRect = CGRect(x: size.width - watermarkWidth - padding, y: padding, width: watermarkWidth, height: watermarkHeight)
        case .topLeft:
            watermarkRect = CGRect(x: padding, y: size.height - watermarkHeight - padding, width: watermarkWidth, height: watermarkHeight)
        case .topRight:
            watermarkRect = CGRect(x: size.width - watermarkWidth - padding, y: size.height - watermarkHeight - padding, width: watermarkWidth, height: watermarkHeight)
        case .center:
            watermarkRect = CGRect(x: (size.width - watermarkWidth) / 2, y: (size.height - watermarkHeight) / 2, width: watermarkWidth, height: watermarkHeight)
        }
        
        // Watermark'ı çiz
        if let cgImage = watermarkImage.cgImage {
            context.saveGState()
            context.draw(cgImage, in: watermarkRect)
            context.restoreGState()
        }
    }
}


extension UIImage {
    
    func resizeImageTo(size: CGSize) -> UIImage? {
        var image: UIImage?
        autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(size, false, 1)
            self.draw(in: CGRect(origin: CGPoint.zero, size: size))
            image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        
        return image
    }
}
