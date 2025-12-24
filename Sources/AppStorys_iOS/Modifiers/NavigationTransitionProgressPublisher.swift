//
//  NavigationTransitionProgressPublisher.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 22/11/25.
//

//
//  NavigationTransitionProgressPublisher.swift
//  AppStorys_iOS
//
//  Supports both gesture-driven and direct navigation fades
//

import SwiftUI
import Combine

@MainActor
class NavigationTransitionProgressPublisher: ObservableObject {
    static let shared = NavigationTransitionProgressPublisher()
    
    @Published var progress: CGFloat = 0.0
    @Published var isTransitioning: Bool = false
    @Published var transitionType: TransitionType = .none
    
    enum TransitionType {
        case none
        case gesture      // Interactive swipe
        case direct       // Button tap / programmatic
    }
    
    private init() {}
    
    func updateProgress(_ newProgress: CGFloat) {
        progress = min(max(newProgress, 0.0), 1.0)
    }
    
    func beginGestureTransition() {
        isTransitioning = true
        transitionType = .gesture
        progress = 0.0
        Logger.debug("▶️ Gesture transition started")
    }
    
    func beginDirectTransition() {
        isTransitioning = true
        transitionType = .direct
        progress = 0.0
        Logger.debug("▶️ Direct transition started")
        
        // Animate progress 0 → 1 over 0.3s
        animateDirectTransition()
    }
    
    func endTransition() {
        isTransitioning = false
        transitionType = .none
        progress = 0.0
        Logger.debug("⏹️ Transition ended")
    }
    
    private func animateDirectTransition() {
        Task {
            let steps = 18 // 0.3s at 60fps
            for i in 1...steps {
                guard transitionType == .direct else { break }
                
                let newProgress = Double(i) / Double(steps)
                updateProgress(newProgress)
                
                try? await Task.sleep(nanoseconds: 16_666_667) // ~60fps
            }
        }
    }
}
