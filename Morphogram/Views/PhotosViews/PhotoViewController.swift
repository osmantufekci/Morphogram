//
//  PhotoViewController.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import SwiftUI
import UIKit

class PhotoViewController: UIViewController {
    var fileName: String?
    var index: Int = 0
    private var imageView: UIImageView!
    private var scrollView: UIScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupImageView()
        loadImage()
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupImageView() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }
    
    private func loadImage() {
        guard let fileName = fileName else { return }
        Task {
            if let image = await loadImageFromFile(fileName: fileName) {
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        }
    }
    
    private func loadImageFromFile(fileName: String) async -> UIImage? {
        // Bu fonksiyonu kendi image yükleme mantığınıza göre uyarlayın
        // Örnek olarak FileManager kullanarak:
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: imagePath.path)
    }
}

extension PhotoViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale > 1 {
            if let image = imageView.image {
                let ratioW = imageView.frame.width / image.size.width
                let ratioH = imageView.frame.height / image.size.height
                
                let ratio = ratioW < ratioH ? ratioW : ratioH
                let newWidth = image.size.width * ratio
                let newHeight = image.size.height * ratio
                
                let conditionLeft = newWidth*scrollView.zoomScale > imageView.frame.width
                let left = 0.5 * (conditionLeft ? newWidth - imageView.frame.width : (scrollView.frame.width - scrollView.contentSize.width))
                
                let conditionTop = newHeight*scrollView.zoomScale > imageView.frame.height
                let top = 0.5 * (conditionTop ? newHeight - imageView.frame.height : (scrollView.frame.height - scrollView.contentSize.height))
                
                scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: top, right: left)
            }
        } else {
            scrollView.contentInset = .zero
        }
    }
}
