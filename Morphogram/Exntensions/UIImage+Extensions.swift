//
//  UIImage+Extensions.swift
//  Morphogram
//
//  Created by Osman Tufekci on 17.02.2025.
//

import SwiftUI

private var pixelBufferCache: [CGSize: CVPixelBuffer] = [:] // Önbelleği tanımla

extension UIImage {
    func pixelBuffer(size: CGSize) -> CVPixelBuffer? {
        if let cachedBuffer = pixelBufferCache[size] {
            return cachedBuffer.copy() // Önbellekten kopyasını döndür (ÖNEMLİ)
        }

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

        pixelBufferCache[size] = buffer // Önbelleğe ekle

        return buffer.copy() // Oluşturulan buffer'ın kopyasını döndür (ÖNEMLİ)
    }
}

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer? {
        var copiedBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        CVPixelBufferGetWidth(self),
                                        CVPixelBufferGetHeight(self),
                                        kCVPixelFormatType_32ARGB, // veya orijinal formatınız
                                        attrs,
                                        &copiedBuffer)

        guard status == kCVReturnSuccess, let buffer = copiedBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0)) // Kaynak buffer'ı da kilitle

        memcpy(CVPixelBufferGetBaseAddress(buffer), CVPixelBufferGetBaseAddress(self), CVPixelBufferGetBytesPerRow(self) * CVPixelBufferGetHeight(self))

        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0)) // Kilidi aç

        return buffer
    }
}
