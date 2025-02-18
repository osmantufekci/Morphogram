import UIKit

enum Resolution {
    case k4K, k1080p, k720p
    
    var size: CGSize {
        return switch self {
        case .k4K: .init(width: 3840, height: 2160)
        case .k1080p: .init(width: 1920, height: 1080)
        case .k720p: .init(width: 1280, height: 720)
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
    private var imageCache = NSCache<NSString, UIImage>()
    private var thumbnailCache = NSCache<NSString, UIImage>()
    private var isDir: UnsafeMutablePointer<ObjCBool>?
    
    private init() {
        baseDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageCache.countLimit = 100 // Maksimum 50 tam boyutlu görüntü
        thumbnailCache.countLimit = 300 // Maksimum 300 thumbnail
        imageCache.totalCostLimit = 250 * 1024 * 1024 // 250 MB
        thumbnailCache.totalCostLimit = 150 * 1024 * 1024 // 150 MB
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
        
        // Önce cache'e bak
        if thumbnail {
            if let cachedImage = thumbnailCache.object(forKey: cacheKey) {
                print("Thumbnail loaded:", cacheKey)
                return cachedImage
            }
        } else {
            if let cachedImage = imageCache.object(forKey: cacheKey) {
                print("Cached Image loaded:", cacheKey, "size:", cachedImage.size)
                return cachedImage
            }
        }
        
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: isDir) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            guard let image = UIImage(data: data) else { return nil }
            
            if downSample {
                return downsample(imageAt: fileURL, to: .k4K)
            } else if thumbnail {
                let thumbnailSize = CGSize(width: 150, height: 150)
                let thumbnailImage = image.preparingThumbnail(of: thumbnailSize) ?? image
                thumbnailCache.setObject(thumbnailImage, forKey: cacheKey)
                imageCache.setObject(image, forKey: fileName as NSString)
                return thumbnailImage
            } else {
                print("Cache Image set:", cacheKey, image.size)
                imageCache.setObject(image, forKey: cacheKey)
                return image
            }
        } catch {
            print("Görüntü yüklenirken hata: \(error)")
            return nil
        }
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
}
