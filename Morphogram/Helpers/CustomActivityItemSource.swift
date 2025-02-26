//
//  CustomActivityItemSource.swift
//  Morphogram
//
//  Created by Osman Tufekci on 20.02.2025.
//
import LinkPresentation
import SwiftUI

class CustomActivityItemSource: NSObject, UIActivityItemSource {
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
        getTemporaryURL()
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return projectName
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return url.pathExtension == "gif" ? "com.compuserve.gif" : "public.mpeg-4"
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.iconProvider = NSItemProvider(contentsOf: self.tempFileURL!)
        metadata.title = "Morphogram"
        metadata.originalURL = URL(fileURLWithPath: "From '\(projectName)' · \(ByteCountFormatter().string(fromByteCount: Int64(try! Data(contentsOf: self.tempFileURL!).count)))")
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
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        guard let items = (activityItems as? [CustomActivityItemSource])?.compactMap({$0.url}) else {
            return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
