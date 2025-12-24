//
//  NavigationTransitionObserver.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 17/11/25.
//
//
//  NavigationTransitionObserver.swift
//  AppStorys_iOS
//
//  Handles both gesture and direct navigation
//

import SwiftUI
import UIKit
import QuartzCore

struct NavigationTransitionObserver: UIViewControllerRepresentable {
    let screenName: String
    let onTransitionComplete: () -> Void
    
    func makeUIViewController(context: Context) -> TransitionDetectorViewController {
        let controller = TransitionDetectorViewController()
        controller.screenName = screenName
        controller.onTransitionComplete = onTransitionComplete
        return controller
    }
    
    func updateUIViewController(_ uiViewController: TransitionDetectorViewController, context: Context) {
        uiViewController.screenName = screenName
        uiViewController.onTransitionComplete = onTransitionComplete
    }
}

class TransitionDetectorViewController: UIViewController {
    var screenName: String = ""
    var onTransitionComplete: (() -> Void)?
    
    private var didHandleTransition = false
    private var displayLink: CADisplayLink?
    private weak var activeCoordinator: UIViewControllerTransitionCoordinator?
    
    deinit {
        stopDisplayLink()
    }
    
    // MARK: - Disappear detection
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Log actual coordinator state
        if let coordinator = transitionCoordinator {
            Logger.debug("🔍 \(screenName) → transitionCoordinator found, isInteractive = \(coordinator.isInteractive)")
        } else {
            Logger.debug("🔍 \(screenName) → NO transitionCoordinator")
        }
        
        // Correct gesture vs direct detection
        if let coordinator = transitionCoordinator,
           coordinator.isInteractive {
            
            // --------------------
            // GESTURE TRANSITION
            // --------------------
            Logger.debug("👋 \(screenName) disappearing [GESTURE]")
            
            activeCoordinator = coordinator
            
            Task { @MainActor in
                NavigationTransitionProgressPublisher.shared.beginGestureTransition()
                startDisplayLink()
            }
            
            coordinator.animate(alongsideTransition: nil) { [weak self] context in
                guard let self = self else { return }
                
                self.stopDisplayLink()
                
                Task { @MainActor in
                    NavigationTransitionProgressPublisher.shared.endTransition()
                }
                
                if context.isCancelled {
                    Logger.info("❌ Gesture cancelled - \(self.screenName) stays visible")
                } else {
                    Logger.info("✅ Gesture completed - \(self.screenName) disappeared")
                }
            }
            
        } else {
            // --------------------
            // DIRECT TRANSITION
            // --------------------
            Logger.debug("👋 \(screenName) disappearing [DIRECT]")
            
            Task { @MainActor in
                NavigationTransitionProgressPublisher.shared.beginDirectTransition()
            }
        }
    }
    
    // MARK: - Appear detection
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didHandleTransition = false
        
        if let coordinator = transitionCoordinator,
           coordinator.isInteractive {
            Logger.debug("🔄 Interactive transition detected for \(screenName) [APPEARING]")
            
            coordinator.animate(alongsideTransition: nil) { [weak self] context in
                guard let self = self else { return }
                if context.isCancelled {
                    self.didHandleTransition = true
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // -------------------------------------------------
        // ⭐ Critical Fix ⭐
        // Restore opacity instantly for DIRECT transitions
        // -------------------------------------------------
        if NavigationTransitionProgressPublisher.shared.transitionType == .direct {
            Logger.debug("🏁 Resetting DIRECT transition on appear for \(screenName)")
            NavigationTransitionProgressPublisher.shared.endTransition()
        }
        
        if !didHandleTransition {
            Logger.info("✅ Direct navigation to \(screenName)")
            onTransitionComplete?()
        }
        
        didHandleTransition = false
        stopDisplayLink()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopDisplayLink()
    }
    
    // MARK: - DisplayLink (gesture only)
    
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateProgress))
        displayLink?.preferredFrameRateRange =
            CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateProgress() {
        guard let coordinator = activeCoordinator else {
            stopDisplayLink()
            return
        }
        
        let progress = coordinator.percentComplete
        
        Task { @MainActor in
            NavigationTransitionProgressPublisher.shared.updateProgress(progress)
        }
    }
}
