//
//  SwipeDismissConfiguration.swift - FIXED
//  AppStorys_iOS
//

import SwiftUI

// MARK: - Configuration
public struct SwipeDismissConfiguration {
    public var dismissThreshold: CGFloat = 120
    public var velocityThreshold: CGFloat = 1000
    public var maxDragDistance: CGFloat = 300
    
    // Dismiss visuals (Dragging Down)
    public var scaleAmount: CGFloat = 0.05
    public var opacityAmount: CGFloat = 0.3
    
    // Stretch visuals (Dragging Up)
    public var maxStretchFactor: CGFloat = 0.15
    public var stretchResistance: CGFloat = 0.001
    
    // Physics
    public var springResponse: Double = 0.35
    public var springDamping: Double = 0.85
    
    @MainActor public static let `default` = SwipeDismissConfiguration()
}

// MARK: - Modifier
public struct SwipeToDismissModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var isDismissing: Bool
    let config: SwipeDismissConfiguration
    let onDismiss: (String) -> Void
    
    @State private var dragOffsetY: CGFloat = 0
    @State private var stretchY: CGFloat = 1.0
    @State private var stretchX: CGFloat = 1.0
    
    // Derived visuals for dismiss (downward)
    private var dragProgress: CGFloat {
        min(max(dragOffsetY / config.maxDragDistance, 0), 1)
    }
    
    private var dismissScale: CGFloat {
        1.0 - (dragProgress * config.scaleAmount)
    }
    
    private var dismissOpacity: Double {
        1.0 - Double(dragProgress * config.opacityAmount)
    }
    
    public func body(content: Content) -> some View {
        content
            // 1. STRETCH TRANSFORMATION (Swipe Up)
            .scaleEffect(x: stretchX, y: stretchY, anchor: .bottom)
        
            // 2. DISMISS TRANSFORMATION (Swipe Down)
            // ✅ FIX: Don't reset when dismissing, maintain the transformation
            .scaleEffect(dismissScale)
            .opacity(dismissOpacity)
            
            // 3. MOVEMENT
            .offset(y: dragOffsetY)
            
            // 4. THE GESTURE
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isDismissing else { return }
                        
                        if abs(value.translation.width) > abs(value.translation.height) {
                            return
                        }
                        
                        let translation = value.translation.height
                        
                        if translation < 0 {
                            // 🏹 STRETCH LOGIC (Dragging Up)
                            dragOffsetY = translation / 14.0
                            let distance = abs(translation)
                            let rubberFactor = min(distance * config.stretchResistance, config.maxStretchFactor)
                            stretchY = 1.0 + rubberFactor
                            stretchX = 1.0 - (rubberFactor * 0.3)
                            
                        } else {
                            // ⬇️ DISMISS LOGIC (Dragging Down)
                            dragOffsetY = translation
                            stretchY = 1.0
                            stretchX = 1.0
                        }
                    }
                    .onEnded { value in
                        if dragOffsetY == 0 { return }
                        
                        let isSwipingDown = dragOffsetY > 0
                        
                        let shouldDismiss = isSwipingDown && (
                            dragOffsetY > config.dismissThreshold ||
                            value.velocity.height > config.velocityThreshold
                        )
                        
                        if shouldDismiss {
                            // ✅ FIX: Animate out smoothly
                            withAnimation(.spring(
                                response: config.springResponse,
                                dampingFraction: config.springDamping
                            )) {
                                dragOffsetY = UIScreen.main.bounds.height
                                stretchX = 1.0
                                stretchY = 1.0
                            }
                            // Call dismiss after animation starts
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onDismiss("swipe")
                            }
                        } else {
                            // SNAP BACK
                            withAnimation(.spring(
                                response: config.springResponse,
                                dampingFraction: config.springDamping
                            )) {
                                dragOffsetY = 0
                                stretchX = 1.0
                                stretchY = 1.0
                            }
                        }
                    }
            )
    }
}

// MARK: - Extensions
extension View {
    public func swipeToDismiss(
        isPresented: Binding<Bool>,
        isDismissing: Binding<Bool>,
        config: SwipeDismissConfiguration = .default,
        onDismiss: @escaping (String) -> Void
    ) -> some View {
        self.modifier(
            SwipeToDismissModifier(
                isPresented: isPresented,
                isDismissing: isDismissing,
                config: config,
                onDismiss: onDismiss
            )
        )
    }
    
    public func swipeDismissBackdrop(
        isDismissing: Bool,
        baseOpacity: Double = 0.85
    ) -> some View {
        self.opacity(isDismissing ? 0.0 : baseOpacity)
    }
}
