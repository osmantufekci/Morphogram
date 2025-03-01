//
//  ImagePicker.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//


import SwiftUI
import SwiftData
import PhotosUI
struct ImagePicker: UIViewControllerRepresentable {
    let completion: ([UIImage]?, Int) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: ([UIImage]?, Int) -> Void
        
        init(completion: @escaping ([UIImage]?, Int) -> Void) {
            self.completion = completion
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard !results.isEmpty else {
                completion(nil, 0)
                return
            }
            
            var images: [UIImage] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    defer { group.leave() }
                    if let image = image as? UIImage {
                        images.append(image)
                    }
                }
            }
            
            group.notify(queue: .main) { [weak self] in
                self?.completion(images, results.count)
            }
        }
    }
}
