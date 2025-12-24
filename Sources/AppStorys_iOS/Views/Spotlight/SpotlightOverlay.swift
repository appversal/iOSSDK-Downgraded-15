//
//  SpotlightOverlay.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//


//
//  SpotlightOverlay.swift
//  AppStorys_iOS
//
//  Reusable spotlight effect - works standalone without backend config
//

import SwiftUI

/// Spotlight overlay that highlights a target element by cutting through a dimmed background
struct SpotlightOverlay: View {
    // MARK: - Configuration
    
    let targetFrame: CGRect
    let padding: CGFloat
    let cornerRadius: CGFloat
    let overlayColor: Color
    let overlayOpacity: Double
    let animationDuration: Double
    
    @State private var isVisible = false
    
    // MARK: - Initializer with Sensible Defaults
    
    init(
        targetFrame: CGRect,
        padding: CGFloat = 8,
        cornerRadius: CGFloat = 12,
        overlayColor: Color = .black,
        overlayOpacity: Double = 0.75,
        animationDuration: Double = 0.3
    ) {
        self.targetFrame = targetFrame
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.overlayColor = overlayColor
        self.overlayOpacity = overlayOpacity
        self.animationDuration = animationDuration
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Full-screen dimmed overlay
                overlayColor
                    .opacity(isVisible ? overlayOpacity : 0)
                
                // Spotlight cutout (removes the overlay where drawn)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(
                        width: targetFrame.width + padding * 2,
                        height: targetFrame.height + padding * 2
                    )
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .blendMode(.destinationOut) // ✅ This cuts through the overlay
                
                // Optional: Subtle glow around spotlight
                if isVisible {
                    spotlightGlow
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: animationDuration), value: isVisible)
        }
        .onAppear {
            isVisible = true
        }
    }
    
    // MARK: - Spotlight Glow
    
    @ViewBuilder
    private var spotlightGlow: some View {
        RoundedRectangle(cornerRadius: cornerRadius + 2)
            .stroke(Color.white.opacity(0.2), lineWidth: 2)
            .frame(
                width: targetFrame.width + padding * 2 + 4,
                height: targetFrame.height + padding * 2 + 4
            )
            .position(x: targetFrame.midX, y: targetFrame.midY)
            .shadow(color: .white.opacity(0.3), radius: 8)
    }
}

// MARK: - Preview

#if DEBUG
struct SpotlightOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Mock screen content
            VStack(spacing: 20) {
                Text("Header").font(.title)
                
                Button("Target Button") {}
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                    .frame(width: 200, height: 50)
                
                Text("Other content")
            }
            
            // Spotlight overlay
            SpotlightOverlay(
                targetFrame: CGRect(x: 100, y: 300, width: 200, height: 50),
                padding: 12,
                cornerRadius: 16
            )
        }
    }
}
#endif
