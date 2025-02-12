//
//  PhotoPageViewController.swift
//  Morphogram
//
//  Created by Osman Tufekci on 11.02.2025.
//
import UIKit
import SwiftUI

struct PhotoPageViewController: UIViewControllerRepresentable {
    let photos: [ProjectPhoto]
    @Binding var currentIndex: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [UIPageViewController.OptionsKey.interPageSpacing: 20]
        )
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        
        let initialVC = context.coordinator.photoViewController(at: currentIndex)
        pageViewController.setViewControllers([initialVC], direction: .forward, animated: false)
        
        return pageViewController
    }
    
    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        if let currentVC = pageViewController.viewControllers?.first as? PhotoViewController {
            if currentVC.index != currentIndex {
                let newVC = context.coordinator.photoViewController(at: currentIndex)
                let direction: UIPageViewController.NavigationDirection = currentVC.index > currentIndex ? .reverse : .forward
                pageViewController.setViewControllers([newVC], direction: direction, animated: true)
            }
        }
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: PhotoPageViewController
        var viewControllers: [Int: PhotoViewController] = [:]
        
        init(_ pageViewController: PhotoPageViewController) {
            self.parent = pageViewController
        }
        
        func photoViewController(at index: Int) -> PhotoViewController {
            if let existingVC = viewControllers[index] {
                return existingVC
            }
            let vc = PhotoViewController()
            vc.index = index
            if index >= 0 && index < parent.photos.count {
                vc.fileName = parent.photos[index].fileName
            }
            viewControllers[index] = vc
            return vc
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PhotoViewController else { return nil }
            let previousIndex = vc.index - 1
            guard previousIndex >= 0 else { return nil }
            return photoViewController(at: previousIndex)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PhotoViewController else { return nil }
            let nextIndex = vc.index + 1
            guard nextIndex < parent.photos.count else { return nil }
            return photoViewController(at: nextIndex)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let currentVC = pageViewController.viewControllers?.first as? PhotoViewController {
                parent.currentIndex = currentVC.index
            }
        }
    }
}
