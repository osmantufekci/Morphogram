import UIKit

enum Resolution: CaseIterable {
    case k720p, k1080p, k4K
    
    var size: CGSize {
        return switch self {
        case .k4K: .init(width: 2160, height: 2880)
        case .k1080p: .init(width: 1080, height: 1440)
        case .k720p: .init(width: 720, height: 960)
        }
    }
    
    var title: String {
        return switch self {
        case .k4K: "4K"
        case .k1080p: "1080p"
        case .k720p: "720p"
        }
    }
    
    var cacheKey: String {
        return switch self {
        case .k4K: "_4K"
        case .k1080p: "_1080p"
        case .k720p: "_720p"
        }
    }
}

final class ImageManager {
    static let shared = ImageManager()
    
    private let fileManager = FileManager.default
    private let appGroupIdentifier = "group.com.Trionode.Morphogram"
    private let baseDirectory: URL
    private var thumbnailCache = NSCache<NSString, UIImage>()
    private var isDir: UnsafeMutablePointer<ObjCBool>?
    private var resolution: Resolution = .k4K
    
    private init() {
        baseDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        thumbnailCache.countLimit = 1000
    }
    
    func generateFileName(forProject projectId: String) -> String {
        let fileName = "\(UUID().uuidString).JPG"
        print("Yeni dosya adı oluşturuldu: \(fileName)")
        return fileName
    }
    
    func saveImage(_ image: UIImage, withFileName fileName: String) -> Bool {
        let fileURL = baseDirectory.appendingPathComponent(fileName, isDirectory: false)
        print("Fotoğraf kaydedilecek: \(fileURL.path)")
        
        guard let data = image.jpegData(compressionQuality: 0.3) else {
            print("Fotoğraf verisi oluşturulamadı")
            return false
        }
        
        do {
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: isDir) {
                try fileManager.removeItem(at: fileURL)
                print("Eski fotoğraf silindi")
            }
            
            fileManager.createFile(atPath: fileURL.path, contents: data)
            
            print("Fotoğraf başarıyla kaydedildi (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
            return true
        } catch {
            print("Fotoğraf kaydedilemedi: \(error)")
            return false
        }
    }
    
    func loadImage(fileName: String, thumbnail: Bool = false, downSample: Bool = false) -> UIImage? {
        let cacheKey = (fileName + (thumbnail ? "_thumb" : "")) as NSString
        
        if thumbnail {
            if let cachedImage = thumbnailCache.object(forKey: cacheKey) {
                print("Thumbnail loaded:", cacheKey)
                return cachedImage
            }
        }
        
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: isDir) else {
            return nil
        }
        
        guard let image = UIImage(contentsOfFile: fileURL.path) else { return nil }
        
        if downSample {
            return downsample(imageAt: fileURL, to: resolution)
        } else if thumbnail {
            let thumbnailSize = CGSize(width: 600, height: 600)
            let thumbnailImage = image.preparingThumbnail(of: thumbnailSize) ?? image
            thumbnailCache.setObject(thumbnailImage, forKey: cacheKey)
            print("Cache Thumbnail set:", cacheKey, thumbnailSize)
            print("Cache Image set:", fileName, image.size)
            return thumbnailImage
        }
        
        return image
    }
    
    func loadImageAsync(fileName: String, thumbnail: Bool = true, downSample: Bool = false, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let image = self.loadImage(fileName: fileName, thumbnail: thumbnail, downSample: downSample) {
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    func deleteImage(fileName: String) {
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        print("Fotoğraf silme denemesi: \(fileURL.path)")
        
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: isDir) else {
            print("Silinecek fotoğraf bulunamadı: \(fileURL.path)")
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
            print("Fotoğraf başarıyla silindi: \(fileName)")
        } catch {
            print("Fotoğraf silinemedi: \(error)")
        }
    }
    
    func verifyImageExists(fileName: String) -> Bool {
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        let exists = fileManager.fileExists(atPath: fileURL.path, isDirectory: isDir)
        print("Fotoğraf kontrolü: \(fileName) - \(exists ? "Mevcut" : "Bulunamadı")")
        return exists
    }
    
    func setResolution(_ resolution: Resolution) {
        self.resolution = resolution
    }
}
