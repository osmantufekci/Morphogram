import SwiftUI

// MARK: - Wiggle Animation
extension View {
    @ViewBuilder
    func wiggle(isActive: Bool) -> some View {
        if isActive {
            modifier(WiggleModifier())
        } else {
            self
        }
    }
}

struct WiggleModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isAnimating ? 2 : -2))
            .animation(
                .easeInOut(duration: 0.13)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
} 
