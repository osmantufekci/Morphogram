//
//  WatermarkOverlay.swift
//  Morphogram
//
//  Created by Osman Tufekci on 18.02.2025.
//
import SwiftUI

struct WatermarkModifier: ViewModifier {
    var position: WatermarkPosition
    var size: CGSize
    
    func body(content: Content) -> some View {
        content.overlay(
            Image("watermark")
                .resizable()
                .frame(width: 120, height: 24, alignment: position.alignment)
                .foregroundColor(.white)
                .padding(),
            alignment: position.alignment
        )
    }
}

struct DatemarkModifier: ViewModifier {
    var position: TextPosition
    var text: String
    var size: CGSize
    var fontSize: Int
    
    func body(content: Content) -> some View {
        content.overlay(
            Text(text)
                .foregroundColor(.orange)
                .font(.system(size: CGFloat(fontSize))).bold()
                .padding(.bottom, position == .bottom ? 32 : 0)
                .padding(.top, position == .top ? 32 : 0)
                .frame(
                    width: size.width * 0.3,
                    height: size.width * 0.3 / (size.width / size.height),
                    alignment: position.alignment
                ),
            alignment: position.alignment
        )
    }
}

extension View {
    
    
    func watermark(position: WatermarkPosition, size: CGSize) -> some View {
        self.modifier(WatermarkModifier(position: position, size: size))
    }
    
    func datemark(position: TextPosition, text: String, size: CGSize, fontSize: CustomFontSize) -> some View {
        self.modifier(DatemarkModifier(position: position, text: text, size: size, fontSize: fontSize.rawValue))
    }
    
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

enum CustomFontSize: Int, CaseIterable {
    case small = 12
    case medium = 24
    case large = 36
    
    var icon: some View {
        switch self {
        case .small:
            Image(systemName: "textformat.size.smaller")
                .resizable()
                .frame(width: 24, height: 12)
        case .medium:
            Image(systemName: "textformat.size.smaller")
                .resizable()
                .frame(width: 24, height: 24)
        case .large:
            Image(systemName: "textformat.size.larger")
                .resizable()
                .frame(width: 36, height: 36)
        }
    }
}
