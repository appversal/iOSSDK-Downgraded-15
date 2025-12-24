//
//  AppStorysScreenModifier.swift
//  AppStorys_iOS
//
//  âœ… ZERO USER CODE: Handles SDK initialization + TabView switches internally
//

import SwiftUI
import UIKit

// MARK: - Screen Modifier with Auto-Initialization + Tab Detection
struct AppStorysScreenModifier: ViewModifier {
    let screenName: String
    let onCampaignsLoaded: ([CampaignModel]) -> Void
    
    @StateObject private var sdk = AppStorys.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var triggerSnapshot = false
    @State private var hasTrackedScreen = false  // â† Add this
    
    func body(content: Content) -> some View {
        content
            .overlay(CaptureContextProviderView(screenName: screenName).allowsHitTesting(false))
            
            // âœ… Add invisible transition observer
            .background(
                NavigationTransitionObserver(screenName: screenName) {
                    // âœ… Only called when transition ACTUALLY completes
                    guard !hasTrackedScreen else {
                        Logger.debug("â­ï¸ Already tracked \(screenName), skipping")
                        return
                    }
                    
                    hasTrackedScreen = true
                    Logger.info("ðŸŽ¯ Transition complete - tracking screen: \(screenName)")
                    AppStorys.trackScreen(screenName) { campaigns in  // ✅ Uses static method with auto-wait
                        onCampaignsLoaded(campaigns)
                    }
                }
                .frame(width: 0, height: 0)  // Invisible
            )
        // âœ… Listen for snapshot trigger
        .onReceive(NotificationCenter.default.publisher(for: .AppStorysTriggerSnapshot)) { notification in
            guard let info = notification.userInfo as? [String: Any],
                  let requestedScreen = info["screen"] as? String,
                  requestedScreen == screenName else { return }
            
            Logger.debug("ðŸ“¸ Received snapshot trigger for \(screenName)")
            triggerSnapshot = true
        }
        // âœ… SwiftUI Snapshot Integration
        .snapshot(trigger: triggerSnapshot) { image in
            Task {
                guard let userId = sdk.currentUserID,
                      let captureManager = sdk.screenCaptureManager else {
                    Logger.warning("âš ï¸ Cannot upload snapshot - SDK not ready")
                    triggerSnapshot = false
                    return
                }
                
                // âœ… Get the root view for element discovery
                guard let rootView = try? sdk.getCaptureView() else {
                    Logger.error("âŒ Cannot get root view for capture")
                    triggerSnapshot = false
                    return
                }
                
                Logger.info("ðŸ“¤ Processing SwiftUI snapshot for \(screenName)")
                
                do {
                    try await captureManager.uploadSwiftUISnapshot(image, screenName: screenName, userId: userId)
                    Logger.info("âœ… SwiftUI snapshot uploaded successfully")
                } catch {
                    Logger.error("âŒ Failed to upload SwiftUI snapshot: \(error)")
                }
                
                triggerSnapshot = false
            }
        }            .onAppear {
                isVisible = true
                hasTrackedScreen = false  // â† Reset flag
                
                Logger.debug("ðŸ“º Screen appeared: \(screenName)")
                
                // âœ… Update currentScreen immediately (for .onDisappear checks)
                // But DON'T call trackScreen yet - let TransitionObserver do it
                sdk.updateCurrentScreenReference(screenName)
            }
            .onDisappear {
                isVisible = false
                hasTrackedScreen = false
                
                Logger.debug("ðŸ‘‹ Screen disappeared: \(screenName)")
                
                if scenePhase == .active {
                    if sdk.currentScreen != screenName {
                        Logger.info("ðŸ’¤ Screen inactive - hiding campaigns immediately")
                        sdk.hideAllCampaignsForDisappearingScreen(screenName)
                        sdk.clearCaptureContext()
                    } else {
                        Logger.info("â¸ï¸ Screen temporarily hidden (potential gesture cancel) - keeping campaigns AND context")
                    }
                } else {
                    Logger.info("ðŸŒ™ App backgrounded - preserving everything")
                }
            }
            .onChangeCompat(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active &&
                   isVisible &&
                   oldPhase == .background {

                    Logger.debug("☀️ App returned to foreground on \(screenName)")
                    AppStorys.trackScreen(screenName) { campaigns in
                        onCampaignsLoaded(campaigns)
                    }
                }
            }
    }
}

// MARK: - âœ… SwiftUI Snapshot Implementation (from article)

fileprivate struct SnapshotModifier: ViewModifier {
    var trigger: Bool
    var onComplete: (UIImage) -> ()
    @State private var view: UIView = .init(frame: .zero)
    
    func body(content: Content) -> some View {
        content
            .background(ViewExtractor(view: view))
            .compositingGroup()
            .onChangeCompat(of: trigger) { _, newValue in
                if newValue {
                    generateSnapshot()
                }
            }
    }
    
    private func generateSnapshot() {
        if let superView = view.superview?.superview {
            let render = UIGraphicsImageRenderer(size: superView.bounds.size)
            let image = render.image { _ in
                superView.drawHierarchy(in: superView.bounds, afterScreenUpdates: true)
            }
            onComplete(image)
        }
    }
}

fileprivate struct ViewExtractor: UIViewRepresentable {
    var view: UIView
    
    func makeUIView(context: Context) -> UIView {
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // no process
    }
}

extension View {
    @ViewBuilder
    fileprivate func snapshot(trigger: Bool, onComplete: @escaping (UIImage) -> ()) -> some View {
        self.modifier(SnapshotModifier(trigger: trigger, onComplete: onComplete))
    }
}

// MARK: - Capture Context Provider

private struct CaptureContextProviderView: UIViewRepresentable {
    @EnvironmentObject private var sdk: AppStorys
    let screenName: String
    
    func makeUIView(context: Context) -> CaptureContextUIView {
        let view = CaptureContextUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: CaptureContextUIView, context: Context) {
        guard sdk.currentScreen == screenName else {
            Logger.debug("⏭ Skipping context update - screen mismatch (\(sdk.currentScreen ?? "nil") != \(screenName))")
            return
        }
        
        // ✅ CRITICAL FIX: Early exit before scan
        if let lastView = sdk.captureContextProvider.currentView,
           let lastWindow = lastView.window,
           let currentWindow = uiView.window,
           lastWindow === currentWindow,
           sdk.captureContextProvider.lastScreenName == screenName {
            Logger.debug("⏭ Skipping redundant scan - same window + screen")
            return
        }
        
        Logger.debug("🔍 Performing hierarchy scan for \(screenName)...")
        
        if let contentView = uiView.findActualContentView() {
            // ✅ Use cached setView() method
            sdk.captureContextProvider.setView(contentView, for: screenName)
        }
    }
}


// MARK: - Safe View Finder Logic

private class CaptureContextUIView: UIView {
    func findActualContentView() -> UIView? {
        Logger.debug("ðŸ” Searching for actual content view...")
        
        var currentView: UIView? = self.superview
        var depth = 0
        let maxDepth = 15
        var candidateViews: [(view: UIView, score: Int, depth: Int)] = []
        
        while let view = currentView, depth < maxDepth {
            let viewType = String(describing: type(of: view))
            
            if depth < 8 {
                Logger.debug("   [\(depth)] \(viewType)")
            }
            
            var score = 0
            
            if viewType.contains("HostingView") {
                score += 80
                Logger.debug("      ðŸŽ¯ HostingView found!")
            }
            if viewType.contains("PlatformViewHost") && !viewType.contains("CaptureContext") {
                score += 70
                Logger.debug("      ðŸŽ¯ PlatformViewHost found!")
            }
            if viewType.contains("UIView") && view.subviews.count > 3 {
                score += 50
            }
            if view.subviews.count > 5 {
                score += 20
            }
            if view.subviews.count > 10 {
                score += 10
            }
            if viewType.contains("CaptureContext") {
                score -= 100
                Logger.debug("      âš ï¸ Skipping bridge container")
            }
            if viewType.contains("TabBar") {
                score -= 50
                Logger.debug("      âš ï¸ Avoiding TabBar view")
            }
            if viewType.contains("Controller") {
                score = 0
                Logger.debug("      âš ï¸ Skipping controller-related view")
            }
            
            if score > 0 {
                candidateViews.append((view, score, depth))
            }
            
            currentView = view.superview
            depth += 1
        }
        
        if let best = candidateViews.max(by: { $0.score < $1.score }) {
            let viewType = String(describing: type(of: best.view))
            Logger.debug("âœ… Selected content view: \(viewType) (score: \(best.score), depth: \(best.depth))")
            
            if !viewType.contains("Controller") && !viewType.contains("TabBar") {
                return best.view
            } else {
                Logger.warning("âš ï¸ Selected view looks unsafe, using fallback")
            }
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.keyWindow {
            Logger.warning("âš ï¸ Using key window as fallback")
            return keyWindow
        }
        
        Logger.error("âŒ Could not find any suitable content view!")
        return nil
    }
}

// MARK: - Public Extension

extension View {
    public func trackAppStorysScreen(
        _ screenName: String,
        onCampaignsLoaded: @escaping ([CampaignModel]) -> Void = { _ in }
    ) -> some View {
        modifier(AppStorysScreenModifier(
            screenName: screenName,
            onCampaignsLoaded: onCampaignsLoaded
        ))
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let AppStorysTriggerSnapshot = Notification.Name("AppStorysTriggerSnapshot")
}

// MARK: - UIKit Swizzling for Tab Detection

extension UIViewController {
    // âœ… Custom notification for view controller visibility
    static let didBecomeVisibleNotification = Notification.Name("UIViewControllerDidBecomeVisible")
    
    static let swizzleViewDidAppear: Void = {
        let originalSelector = #selector(viewDidAppear(_:))
        let swizzledSelector = #selector(appstorys_viewDidAppear(_:))
        
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    @objc private func appstorys_viewDidAppear(_ animated: Bool) {
        // Call original implementation
        self.appstorys_viewDidAppear(animated)
        
        // Post notification for tab detection
        NotificationCenter.default.post(
            name: UIViewController.didBecomeVisibleNotification,
            object: self
        )
    }
}
