//
//  Utility.swift
//  Morphogram
//
//  Created by Osman Tufekci on 12.02.2025.
//

import Foundation
import UIKit
import AVFoundation

final class Utility {
    class func getThumbnailImage(forUrl url: URL) -> UIImage {
        let asset: AVAsset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        do {
            let thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 1, timescale: 60), actualTime: nil)
            return UIImage(cgImage: thumbnailImage)
        } catch let error {
            print(error)
        }
        
        do {
            let image = UIImage(
                data: try Data(contentsOf: url)
            ) ?? .init()
            return image
        } catch let error {
            print(error)
        }
        
        return UIImage()
    }
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

func downsample(imageAt imageURL: URL,
                to resolution: Resolution) -> UIImage? {
    // Create an CGImageSource that represent an image
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
        return nil
    }
    
    // Calculate the desired dimension
    let maxDimensionInPixels = max(resolution.size.width, resolution.size.height)
    
    // Perform downsampling
    let downsampleOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
    ] as CFDictionary
    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
        return nil
    }
    
    print("Downsampled image loaded:", imageURL.lastPathComponent, "size:", downsampledImage.height, downsampledImage.width)
    return UIImage(cgImage: downsampledImage)
}
