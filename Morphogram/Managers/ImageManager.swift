import UIKit

final class ImageManager {
    static let shared = ImageManager()
    
    private let fileManager = FileManager.default
    private let appGroupIdentifier = "group.com.Trionode.Morphogram"
    private let baseDirectory: URL
    private var imageCache = NSCache<NSString, UIImage>()
    private var thumbnailCache = NSCache<NSString, UIImage>()
    
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
        
        guard let data = image.jpegData(compressionQuality: 0.1) else {
            print("Fotoğraf verisi oluşturulamadı")
            return false
        }
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
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
                return cachedImage
            }
        } else {
            if let cachedImage = imageCache.object(forKey: cacheKey) {
                return cachedImage
            }
        }
        
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            guard let image = UIImage(data: data) else { return nil }
            
            if downSample {
                return downsample(imageAt: fileURL, to: CGSize(width: UIScreen.main.bounds.width * 0.95, height: 450))
            } else if thumbnail {
                // Thumbnail oluştur
                let thumbnailSize = CGSize(width: 200, height: 200)
                let thumbnailImage = image.preparingThumbnail(of: thumbnailSize) ?? image
                thumbnailCache.setObject(thumbnailImage, forKey: cacheKey)
                return thumbnailImage
            } else {
                imageCache.setObject(image, forKey: cacheKey)
                return image
            }
        } catch {
            print("Görüntü yüklenirken hata: \(error)")
            return nil
        }
    }
    
    func loadImageAsync(fileName: String, thumbnail: Bool = true, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let image = self.loadImage(fileName: fileName, thumbnail: thumbnail) {
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    func deleteImage(fileName: String) {
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        print("Fotoğraf silme denemesi: \(fileURL.path)")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
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
        let exists = fileManager.fileExists(atPath: fileURL.path)
        print("Fotoğraf kontrolü: \(fileName) - \(exists ? "Mevcut" : "Bulunamadı")")
        return exists
    }
    
    func clearCache() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
}
