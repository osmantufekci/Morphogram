//
//  CustomActivityItemSource.swift
//  Morphogram
//
//  Created by Osman Tufekci on 20.02.2025.
//
import LinkPresentation
import SwiftUI
import AVFoundation

final class CustomActivityItemSource: NSObject, UIActivityItemSource {
    let url: URL
    let projectName: String
    var tempFileURL: URL?
    
    init(url: URL, projectName: String) {
        self.url = url
        self.projectName = projectName
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        getPlaceHolderImage() ?? url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        getTemporaryURL() ?? url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return projectName
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return url.pathExtension == "gif" ? "com.compuserve.gif" : "public.mpeg-4"
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        if let tempFileURL {
            metadata.iconProvider = NSItemProvider(contentsOf: tempFileURL)
        } else {
            metadata.iconProvider = NSItemProvider(object: getThumbnailImage(forUrl: url))
        }
        metadata.title = "Morphogram"
        metadata.originalURL = URL(fileURLWithPath: "From '\(projectName)' · \(ByteCountFormatter().string(fromByteCount: Int64(try! Data(contentsOf: self.tempFileURL ?? url).count)))")
        return metadata
    }
    
    func getTemporaryURL() -> URL? {
        if let imageData = try? Data(contentsOf: url),
           let image = UIImage(data: imageData) {
            
            // Yönelimi düzelt ve yeni bir dosya oluştur
            let correctedImage = image.fixImageOrientation()
            
            // Geçici bir dosya oluştur
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent(url.lastPathComponent)
            
            // Düzeltilmiş görüntüyü kaydet
            if let correctedData = correctedImage?.jpegData(compressionQuality: 1.0) {
                try? correctedData.write(to: tempFileURL)
                return tempFileURL
            }
        }
        
        return nil
    }
    
    func getPlaceHolderImage() -> UIImage? {
        if let imageData = try? Data(contentsOf: url),
           let image = UIImage(data: imageData) {
            
            // Yönelimi düzelt ve yeni bir dosya oluştur
            let correctedImage = image.fixImageOrientation()
            
            // Geçici bir dosya oluştur
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent(url.lastPathComponent)
            self.tempFileURL = tempFileURL
            
            // Düzeltilmiş görüntüyü kaydet
            if let correctedData = correctedImage?.jpegData(compressionQuality: 1.0) {
                try? correctedData.write(to: tempFileURL)
                return image
            }
        }
    
        return nil
    }
    
    func getThumbnailImage(forUrl url: URL) -> UIImage {
        let asset: AVAsset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        do {
            let thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 1, timescale: 60), actualTime: nil)
            return UIImage(cgImage: thumbnailImage)
        } catch let error {
            print(error)
        }
        
        return UIImage()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
