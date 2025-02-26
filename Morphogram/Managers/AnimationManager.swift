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
        var chosenImages = images
        let imageCount = Float(images.count)
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
                    var appendSucceeded = true
                    
                    while (!chosenImages.isEmpty) {
                        if (videoWriterInput.isReadyForMoreMediaData) {
                            guard var nextPhoto = ImageManager.shared.loadImage(fileName: chosenImages.remove(at: 0)) else { continue }
                            let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
                            let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                            
                            var pixelBuffer: CVPixelBuffer? = nil
                            let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                            
                            if let pixelBuffer = pixelBuffer,
                               status == 0 {
                                let managedPixelBuffer = pixelBuffer
                                
                                CVPixelBufferLockBaseAddress(managedPixelBuffer, [])
                                
                                let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                                let context = CGContext(
                                    data: data,
                                    width: Int(outputSize.size.width),
                                    height: Int(outputSize.size.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer),
                                    space: rgbColorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                )
                                
                                autoreleasepool {
                                    if let fixedPhoto = nextPhoto.fixImageOrientation() {
                                        nextPhoto = fixedPhoto
                                }
                            }
                            
                            context?.clear(CGRect(x: 0, y: 0, width: outputSize.size.width, height: outputSize.size.height))
                            
                            context?.draw(nextPhoto.cgImage!, in: CGRect(x: 0, y: 0, width: outputSize.size.width, height: outputSize.size.height))
                            
                            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, [])
                            
                            appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        } else {
                            print("Failed to allocate pixel buffer")
                            appendSucceeded = false
                        }
                    }
                    if !appendSucceeded {
                        onProgress?(0)
                        return
                    }
                    frameCount += 1
                    print("Progress:", Float(frameCount) / imageCount, "(\(frameCount) / \( imageCount) Images: \(chosenImages.count)")
                    onProgress?(Float(frameCount) / imageCount)
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
                kCGImagePropertyGIFLoopCount as String: loopCount,
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
