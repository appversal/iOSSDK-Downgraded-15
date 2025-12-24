//
//  CaptureContextProvider.swift
//  AppStorys_iOS
//
//  âœ… FIXED: Properly detects NavigationStack content vs TabView root
//

import SwiftUI
import UIKit

// MARK: - Capture Context Provider
@MainActor
class CaptureContextProvider: ObservableObject {
    weak var currentView: UIView?
    private(set) var lastScreenName: String?
    private var updateTask: Task<Void, Never>?
    private var lastViewIdentity: ObjectIdentifier?
    
    func shouldUpdateView(_ proposedView: UIView, for screenName: String) -> Bool {
        let proposedIdentity = ObjectIdentifier(proposedView)
        
        if lastScreenName == screenName && lastViewIdentity == proposedIdentity {
            return false
        }
        
        return true
    }
    
    func setView(_ view: UIView, for screenName: String) {
        guard shouldUpdateView(view, for: screenName) else {
            Logger.debug("⏭ Skipping redundant scan for \(screenName)")
            return
        }
        
        // ✅ FIX: Set view immediately (no delay)
        let proposedIdentity = ObjectIdentifier(view)
        self.currentView = view
        self.lastScreenName = screenName
        self.lastViewIdentity = proposedIdentity
        
        // ✅ Only debounce the logging (not the assignment)
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            guard !Task.isCancelled else { return }
            
            // Verify view is still current after delay
            guard self.lastViewIdentity == proposedIdentity else {
                Logger.debug("⏭ View changed during debounce, skipping log")
                return
            }
            
            let viewType = String(describing: type(of: view))
            Logger.debug("🔧 Context updated: \(viewType) for \(screenName)")
        }
    }
    
    func clearContext() {
        updateTask?.cancel()
        currentView = nil
        lastScreenName = nil
        lastViewIdentity = nil
        Logger.info("🧹 Capture context cleared")
    }
}


// MARK: - View Extension for Capture Context

extension View {
    public func captureContext() -> some View {
        background(CaptureContextView())
    }
}

// MARK: - Internal Implementation

private struct CaptureContextView: UIViewRepresentable {
    @EnvironmentObject private var sdk: AppStorys
    
    func makeUIView(context: Context) -> CaptureContextUIView {
        let view = CaptureContextUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: CaptureContextUIView, context: Context) {
        // 🚫 Skip global context updates when no tracked screen is active
        guard let screenName = sdk.currentScreen else {
            if Self.lastLoggedNilContext != true {
                Logger.debug("🚫 Global CaptureContextProvider skipped — no active tracked screen")
                Self.lastLoggedNilContext = true
            }
            return
        }
        
        Self.lastLoggedNilContext = false
        
        // ✅ CRITICAL FIX: Check cache BEFORE expensive scan
        // Quick lightweight check using window identity
        if let lastView = sdk.captureContextProvider.currentView,
           let lastWindow = lastView.window,
           let currentWindow = uiView.window,
           lastWindow === currentWindow,
           sdk.captureContextProvider.lastScreenName == screenName {
            Logger.debug("⏭ Skipping redundant scan - same window + screen (\(screenName))")
            return
        }
        
        // ✅ Only scan if cache check failed
        Logger.debug("🔍 Performing hierarchy scan for \(screenName)...")
        
        if let contentView = uiView.findActualContentView() {
            // ✅ Use the cached setView() method (not setCaptureContext)
            sdk.captureContextProvider.setView(contentView, for: screenName)
        } else {
            Logger.warning("⚠️ Could not find content view for capture context")
        }
    }

    private static var lastLoggedNilContext: Bool?
}

private class CaptureContextUIView: UIView {
    /// Find the actual visible content view
    func findActualContentView() -> UIView? {
        Logger.debug("ðŸ” Searching for actual content view (hybrid Tab + Nav deep mode)...")

        // âœ… Find key window
        guard let window = self.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: \.isKeyWindow) else {
            Logger.warning("âš ï¸ No window available")
            return nil
        }

        var bestCandidate: UIView?

        // MARK: - Recursive traversal to find best HostingView
        func traverse(_ view: UIView, depth: Int = 0) {
            guard depth < 25 else { return }
            let viewType = String(describing: type(of: view))

            // Skip irrelevant wrappers
            if viewType.contains("CaptureContext")
                || viewType.contains("UIViewControllerWrapper")
                || viewType.contains("TransitionView")
                || viewType.contains("Controller") {
                return
            }

            // âœ… Detect HostingView with visible tagged elements
            if viewType.contains("HostingView"),
               !viewType.contains("TabBar"),
               view.bounds.height > 100,
               view.containsTaggedElement() {
                Logger.debug("ðŸŽ¯ Leaf HostingView candidate: \(viewType) with tagged content âœ…")
                bestCandidate = view
            }

            // âœ… Detect Tab-based HostingView (bottom tabs)
            if viewType.contains("HostingView"),
               view.superview?.description.contains("UIKitAdaptableTabView") == true {
                Logger.debug("ðŸŽ¯ Tab HostingView candidate: \(viewType)")
                bestCandidate = view
            }

            // Recurse
            for sub in view.subviews {
                traverse(sub, depth: depth + 1)
            }
        }

        traverse(window)

        // MARK: - Pick best candidate or fallback
        if let best = bestCandidate {
            if best.window != nil, best.containsTaggedElement() {
                Logger.info("ðŸŽ¯ Selected content view for capture: \(type(of: best)) frame:\(best.frame)")
                return best
            } else if let visibleSub = best.findVisibleHostingDescendant() {
                Logger.info("ðŸŽ¯ Using visible descendant HostingView for capture: \(type(of: visibleSub)) frame:\(visibleSub.frame)")
                return visibleSub
            } else {
                Logger.warning("âš ï¸ Best candidate not visible â€” falling back to window")
                return window
            }
        }

        // âœ… Deep fallback to the deepest visible HostingView
        if let fallback = window.deepestHostingView() {
            Logger.warning("âš ï¸ Using deepest HostingView as fallback: \(type(of: fallback)) frame:\(fallback.frame)")
            return fallback
        }

        Logger.error("âŒ No suitable content view found, returning window")
        return window
    }


}

// MARK: - AppStorys Extension

extension AppStorys {
    private static var captureContext: CaptureContextProvider = CaptureContextProvider()
    
    // ✅ DEPRECATED: Remove this method - use captureContextProvider.setView() instead
    // func setCaptureContext(_ view: UIView) {
    //     Self.captureContext.currentView = view
    // }
    
    func getCaptureView() throws -> UIView {
        if let contextView = Self.captureContext.currentView {
            let viewType = String(describing: type(of: contextView))
            Logger.debug("📸 Using context view: \(viewType)")
            return contextView
        }
        
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow ?? scene.windows.first else {
            Logger.error("❌ No window available for capture")
            throw ScreenCaptureError.noActiveScreen
        }
        
        Logger.warning("⚠️ Using fallback window - add .captureContext() to your NavigationStack content!")
        return window
    }

    /// ✅ Public accessor for context provider
    var captureContextProvider: CaptureContextProvider {
        return Self.captureContext
    }
    
    func clearCaptureContext() {
        Self.captureContext.clearContext() // ✅ Use the provider's method
    }
    
    func isScreenCurrentlyVisible(_ name: String) -> Bool {
        return captureContextProvider.currentView != nil && currentScreen == name
    }
}


// MARK: - ðŸ” Debug Helper: Dump Entire View Hierarchy
extension UIView {
    func dumpHierarchy(
        depth: Int = 0,
        prefix: String = ""
    ) {
        let indent = String(repeating: "  ", count: depth)
        let viewType = String(describing: type(of: self))
        let frameString = "(\(Int(frame.origin.x)), \(Int(frame.origin.y)), \(Int(frame.width)), \(Int(frame.height)))"
        let id = accessibilityIdentifier ?? "nil"
        Logger.debug("\(indent)â€¢ \(prefix)\(viewType)  id:\(id)  frame:\(frameString)  alpha:\(alpha)  window:\(window != nil ? "âœ…" : "âŒ")")

        // Avoid infinite recursion for huge trees
        guard depth < 25 else {
            Logger.debug("\(indent)  â€¦ (depth limit reached)")
            return
        }

        for (index, sub) in subviews.enumerated() {
            sub.dumpHierarchy(depth: depth + 1, prefix: "[\(index)] ")
        }
    }
}

// MARK: - UIView Utilities
private extension UIView {

    /// Finds visible HostingView deeper in hierarchy (attached to window and containing tags)
    func findVisibleHostingDescendant() -> UIView? {
        var candidate: UIView?

        func recurse(_ view: UIView) {
            let typeName = String(describing: type(of: view))
            if typeName.contains("HostingView"),
               view.window != nil,
               view.containsTaggedElement() {
                candidate = view
            }
            for sub in view.subviews {
                recurse(sub)
            }
        }

        recurse(self)
        return candidate
    }

    /// Checks recursively if any subview contains an AppStorys tag
    func containsTaggedElement() -> Bool {
        if let id = accessibilityIdentifier,
           id.starts(with: "APPSTORYS_") {
            return true
        }
        for sub in subviews where sub.containsTaggedElement() {
            return true
        }
        return false
    }

    /// Fallback: returns the deepest visible HostingView
    func deepestHostingView() -> UIView? {
        var result: UIView?
        func dive(_ view: UIView) {
            if String(describing: type(of: view)).contains("HostingView"),
               view.window != nil {
                result = view
            }
            for sub in view.subviews {
                dive(sub)
            }
        }
        dive(self)
        return result
    }
    
    
}
