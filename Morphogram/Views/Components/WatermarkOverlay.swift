//
//  WatermarkOverlay.swift
//  Morphogram
//
//  Created by Osman Tufekci on 18.02.2025.
//
import SwiftUI

struct WatermarkOverlay: View {
    let position: WatermarkPosition
    
    var body: some View {
        Text("Morphogram")
            .font(.system(size: 35, weight: .bold))
            .foregroundColor(.white)
            .opacity(0.10)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    }
}