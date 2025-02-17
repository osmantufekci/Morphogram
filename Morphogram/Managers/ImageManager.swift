import UIKit

class ImageManager {
    static let shared = ImageManager()
    
    private let fileManager = FileManager.default
    private let appGroupIdentifier = "group.com.Trionode.Morphogram"
    
    private init() {
        printDirectoryContents()
    }
    
    private var baseDirectory: URL {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents dizini bulunamadı")
        }
        print("Belge dizini: \(documentsDirectory.path)")
        return documentsDirectory
    }
    
    private func printDirectoryContents() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
            print("Dizin içeriği (\(contents.count) dosya):")
            contents.forEach { print("- \($0.lastPathComponent)") }
        } catch {
            print("Dizin içeriği okunamadı: \(error)")
        }
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
            printDirectoryContents()
            return true
        } catch {
            print("Fotoğraf kaydedilemedi: \(error)")
            return false
        }
    }
    
    func loadImage(fileName: String) -> UIImage? {
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        print("Fotoğraf yükleme denemesi: \(fileURL.path)")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("Fotoğraf bulunamadı: \(fileURL.path)")
            printDirectoryContents()
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            print("Dosya okundu (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
            
            if let image = UIImage(data: data) {
                print("Fotoğraf başarıyla yüklendi: \(fileName)")
                return image
            } else {
                print("Fotoğraf verisi görüntüye dönüştürülemedi: \(fileName)")
                return nil
            }
        } catch {
            print("Fotoğraf yüklenirken hata oluştu: \(error)")
            return nil
        }
    }
    
    func loadImageAsync(fileName: String, completion: @escaping (UIImage) -> Void) {
        print("Asenkron fotoğraf yükleme başlatıldı: \(fileName)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                print("ImageManager instance nil")
                return 
            }
            if let image = self.loadImage(fileName: fileName) {
                completion(image)
            }
        }
    }
    
    func deleteImage(fileName: String) {
        let fileURL = baseDirectory.appendingPathComponent(fileName)
        print("Fotoğraf silme denemesi: \(fileURL.path)")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("Silinecek fotoğraf bulunamadı: \(fileURL.path)")
            printDirectoryContents()
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
            print("Fotoğraf başarıyla silindi: \(fileName)")
            printDirectoryContents()
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
}
