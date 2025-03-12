//
//  UIImage+Extensions.swift
//  Morphogram
//
//  Created by Osman Tufekci on 17.02.2025.
//

import SwiftUI

extension UIImage {
    func getTransform(by size: CGSize) -> CGAffineTransform? {
        if self.imageOrientation == .up {
            return nil
        }
        
        var transform = CGAffineTransform.identity
        
        switch self.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        return transform
    }
    
    func fixImageOrientation(by size: CGSize? = nil) -> UIImage? {
        // Eğer görüntü yönelimi zaten doğruysa (.up), doğrudan döndür
        
        let outputSize = size ?? self.size
        
        if self.imageOrientation == .up {
            return self
        }
        
        var transform = CGAffineTransform.identity
        
        switch self.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: outputSize.width, y: outputSize.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: outputSize.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: outputSize.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: outputSize.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: outputSize.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        // Düzeltilmiş görüntüyü oluştur
        let ctx = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        ctx.concatenate(transform)
        
        switch self.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: outputSize.height, height: outputSize.width))
        default:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))
        }
        
        let cgimg = ctx.makeImage()!
        let img = UIImage(cgImage: cgimg)
        
        return img
    }
}
