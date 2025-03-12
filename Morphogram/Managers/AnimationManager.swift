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
        watermarkPosition: WatermarkPosition = .center,
        maxLoopCount: Int = 0,
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
            
            videoWriterInput.requestMediaDataWhenReady(on: mediaQueue, using: {
                let fps: Int32 = Int32(frameRate)
                let frameDuration = CMTimeMake(value: 1, timescale: fps)
                
                var frameCount: Int64 = 0
                var currentLoopCount = 0
                var appendSucceeded = true
                
                let targetLoopCount = maxLoopCount <= 1 ? 1 : maxLoopCount
                
                while currentLoopCount < targetLoopCount && appendSucceeded {
                    for imageName in originalImages {
                        if !videoWriterInput.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.1)
                            continue
                        }
                        
                        guard let nextPhoto = ImageManager.shared.loadImage(fileName: imageName) else { continue }
                        
                        let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                        
                        var pixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                        
                        if let pixelBuffer = pixelBuffer, status == 0 {
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
                            
                            if let transform = nextPhoto.getTransform(by: outputSize.size) { context?.concatenate(transform) }
                            
                            switch nextPhoto.imageOrientation {
                            case .left, .leftMirrored, .right, .rightMirrored:
                                context?.draw(nextPhoto.cgImage!, in: CGRect(x: 0, y: 0, width: outputSize.size.height, height: outputSize.size.width))
                            default:
                                context?.draw(nextPhoto.cgImage!, in: CGRect(x: 0, y: 0, width: outputSize.size.width, height: outputSize.size.height))
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
    
    func createGIF(
        from images: [String],
        frameDelay: Double = 0.5,
        name: String,
        resolution outputSize: Resolution,
        watermarkPosition: WatermarkPosition = .center,
        maxLoopCount: Int = 0,
        onProgress: ((Float) -> Void)? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard !images.isEmpty else {
                completion(nil)
                return
            }
            
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).gif")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                do {
                    try FileManager.default.removeItem(atPath: outputURL.path)
                } catch {
                    fatalError("Unable to delete file: \(error) : \(#function).")
                }
            }
            
            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, images.count, nil) else {
                completion(nil)
                return
            }
            
            let frameProperties = [kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFLoopCount as String: maxLoopCount,
                kCGImagePropertyColorModel as String: kCGImagePropertyColorModelRGB,
                kCGImagePropertyGIFHasGlobalColorMap as String: true,
                kCGImagePropertyDepth as String: 8,
                kCGImagePropertyHasAlpha as String: false
            ]]
            
            CGImageDestinationSetProperties(destination, frameProperties as CFDictionary)
            
            let totalImages = Float(images.count)
            var chosenImages = images
            var frameCount = 0
            
            while(!chosenImages.isEmpty) {
                guard let cgImage = ImageManager.shared.loadImage(fileName: chosenImages.remove(at: 0))?.cgImage else { continue }
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary?)
                frameCount += 1
                onProgress?(Float(frameCount) / totalImages)
            }
            
            completion(CGImageDestinationFinalize(destination) ? outputURL : nil)
        }
    }
}

