//
//  GuideType.swift
//  Morphogram
//
//  Created by Osman Tufekci on 14.02.2025.
//


import SwiftUI
import SwiftData

enum GuideType {
    case none
    case grid3x3
    case grid5x5
    case oval
}

struct GuideOverlay: View {
    let guideType: GuideType
    
    var body: some View {
        switch guideType {
        case .none:
            EmptyView()
        case .grid3x3:
            Grid3x3Guide()
        case .grid5x5:
            Grid5x5Guide()
        case .oval:
            OvalGuide()
        }
    }
}

struct Grid3x3Guide: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dikey çizgiler
                ForEach(1...2, id: \.self) { index in
                    let x = geometry.size.width * (CGFloat(index) / 3.0)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                }
                
                // Yatay çizgiler
                ForEach(1...2, id: \.self) { index in
                    let y = geometry.size.height * (CGFloat(index) / 3.0)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                }
            }
        }
    }
}

struct Grid5x5Guide: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dikey çizgiler
                ForEach(1...4, id: \.self) { index in
                    let x = geometry.size.width * (CGFloat(index) / 5.0)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                }
                
                // Yatay çizgiler
                ForEach(1...4, id: \.self) { index in
                    let y = geometry.size.height * (CGFloat(index) / 5.0)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                }
            }
        }
    }
}

struct OvalGuide: View {
    var body: some View {
        GeometryReader { geometry in
            let shorterSide = min(geometry.size.width, geometry.size.height)
            let ovalSize = shorterSide * 0.7
            
            Ellipse()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                .frame(width: ovalSize, height: shorterSide)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}