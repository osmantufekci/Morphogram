//
//  VideoWriter.swift
//  Morphogram
//
//  Created by Osman Tufekci on 17.02.2025.
//
import UIKit
import AVFoundation
import ImageIO

final class VideoWriter {
    private var assetWriter: AVAssetWriter
    private var assetWriterInput: AVAssetWriterInput
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    init(settings: RenderSettings) throws {
        assetWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: settings.videoFilepath), fileType: .mp4)
        
        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings.videoSettings)
        assetWriterInput.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: settings.size.width,
            kCVPixelBufferHeightKey as String: settings.size.height
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
