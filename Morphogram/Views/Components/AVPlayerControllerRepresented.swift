//
//  AVPlayerControllerRepresented.swift
//  Morphogram
//
//  Created by Osman Tufekci on 14.03.2025.
//
import AVKit
import SwiftUI

struct AVPlayerControllerRepresented : UIViewControllerRepresentable {
    @Binding var player : AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
