//
//  ElementRegistry.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Separate elements from widgets with different prefixes
//

import UIKit
import SwiftUI

@MainActor
public class ElementRegistry: ObservableObject {
    
    // MARK: - Published State
    
    @Published public private(set) var elementFrames: [String: CGRect] = [:]
    @Published public private(set) var lastScanTime: Date?
    
    // MARK: - Configuration
    
    private let elementPrefix = "APPSTORYS_ELEMENT_"
    private let widgetPrefix = "APPSTORYS_WIDGET_"
    private let cacheValidityDuration: TimeInterval = 2.0
    
    // MARK: - Weak References
    
    private weak var currentRootView: UIView?
    
    // MARK: - Public API
    
    public func discoverElements(
        in rootView: UIView,
        forceRefresh: Bool = false
    ) -> [String: CGRect] {
        if !forceRefresh,
           let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < cacheValidityDuration,
           currentRootView === rootView {
            Logger.debug("✅ Using cached elements (\(elementFrames.count) elements)")
            return elementFrames
        }
        
        Logger.debug("🔍 Scanning view hierarchy for tagged elements...")
        Logger.debug("   Starting from: \(type(of: rootView))")
        
        currentRootView = rootView
        var discovered: [String: CGRect] = [:]
        let pixelRatio = UIScreen.main.scale
        
        // ✅ STEP 1: Scan the provided view
        scanView(rootView, into: &discovered, pixelRatio: pixelRatio)
        
        // ✅ STEP 2: Try to detect TabBar in ALL windows (more reliable)
        detectTabBarInAllWindows(into: &discovered, pixelRatio: pixelRatio)
        
        // ✅ STEP 3: Fallback to scanning all windows if nothing found
        if discovered.isEmpty {
            Logger.warning("⚠️ No elements found in rootView, scanning all windows...")
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                Logger.error("❌ No window scene available")
                elementFrames = discovered
                lastScanTime = Date()
                return discovered
            }
            
            for window in windowScene.windows {
                let windowType = String(describing: type(of: window))
                Logger.debug("   🪟 Scanning window: \(windowType)")
                scanView(window, into: &discovered, pixelRatio: pixelRatio)
                
                if !discovered.isEmpty {
                    Logger.info("   ✅ Found \(discovered.count) elements in \(windowType)")
                    break
                }
            }
        }
        
        elementFrames = discovered
        lastScanTime = Date()
        
        // ✅ Enhanced logging with breakdown
        let tabBarElements = discovered.filter { $0.key.starts(with: "tab_") || $0.key == "tab_bar" }
        let widgetElements = discovered.filter { $0.key.starts(with: "widget_") }
        let regularElements = discovered.filter {
            !$0.key.starts(with: "tab_") &&
            !$0.key.starts(with: "widget_") &&
            $0.key != "tab_bar"
        }
        
        if !discovered.isEmpty {
            Logger.info("✅ Discovered \(discovered.count) elements total:")
            if !regularElements.isEmpty {
                Logger.info("   - \(regularElements.count) regular elements")
            }
            if !widgetElements.isEmpty {
                Logger.info("   - \(widgetElements.count) widgets")
            }
            if !tabBarElements.isEmpty {
                Logger.info("   - \(tabBarElements.count) TabBar elements")
            }
        } else {
            Logger.info("ℹ️ No elements found (this may be expected for some screens)")
        }
        
        return discovered
    }
    
    public func getFrame(for id: String) -> CGRect? {
        return elementFrames[id]
    }
    
    public func hasElement(_ id: String) -> Bool {
        return elementFrames[id] != nil
    }
    
    public func invalidateCache() {
        Logger.debug("🔄 Cache invalidated")
        lastScanTime = nil
    }
    
    public func clear() {
        elementFrames.removeAll()
        lastScanTime = nil
        currentRootView = nil
        Logger.debug("🧹 Registry cleared")
    }
    
    // MARK: - Element Extraction with Type Separation
    
    /// Extract regular elements (non-widgets) for /identify-elements/
    public func extractLayoutData() -> [LayoutElement] {
        let pixelRatio = UIScreen.main.scale
        
        // ✅ Filter out widgets - only send regular elements
        return elementFrames
            .filter { !$0.key.hasPrefix("widget_") }
            .map { id, frame in
                LayoutElement(
                    id: id,
                    frame: LayoutFrame(
                        x: Int(frame.origin.x * pixelRatio),
                        y: Int(frame.origin.y * pixelRatio),
                        width: Int(frame.size.width * pixelRatio),
                        height: Int(frame.size.height * pixelRatio)
                    ),
                    type: "UIView",
                    depth: 0
                )
            }
    }
    
    /// Extract widget IDs only for /identify-positions/
    public func extractWidgetIds() -> [String] {
        // ✅ Only return widget IDs
        return elementFrames.keys
            .filter { $0.hasPrefix("widget_") }
            .sorted()
    }
    
    // MARK: - ✅ ENHANCED: Smart TabBar Detection
    
    private func detectTabBarInAllWindows(
        into discovered: inout [String: CGRect],
        pixelRatio: CGFloat
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            Logger.debug("⏭️ No window scene available for TabBar detection")
            return
        }
        
        for window in windowScene.windows {
            if let tabBar = findTabBar(in: window) {
                if isTabBarVisible(tabBar, in: window) {
                    Logger.debug("✅ TabBar is visible - will include in capture")
                    processTabBar(tabBar, window: window, into: &discovered, pixelRatio: pixelRatio)
                } else {
                    Logger.debug("⏭️ TabBar exists but is not visible - skipping (this is normal for internal screens)")
                }
                return
            }
        }
        
        Logger.debug("⏭️ No TabBar found in view hierarchy (this is normal for some screens)")
    }
    
    private func isTabBarVisible(_ tabBar: UITabBar, in window: UIWindow) -> Bool {
        guard tabBar.superview != nil else { return false }
        guard !tabBar.isHidden else { return false }
        guard tabBar.alpha > 0.01 else { return false }
        guard tabBar.window != nil else { return false }
        
        let frame = tabBar.convert(tabBar.bounds, to: window)
        guard frame.width > 0 && frame.height > 0 else { return false }
        
        let screenBounds = window.bounds
        guard frame.intersects(screenBounds) else {
            Logger.debug("   TabBar is off-screen")
            return false
        }
        
        let intersection = frame.intersection(screenBounds)
        let visibleRatio = (intersection.width * intersection.height) / (frame.width * frame.height)
        
        if visibleRatio < 0.3 {
            Logger.debug("   TabBar only \(Int(visibleRatio * 100))% visible - considering hidden")
            return false
        }
        
        return true
    }
    
    private func processTabBar(
        _ tabBar: UITabBar,
        window: UIWindow,
        into discovered: inout [String: CGRect],
        pixelRatio: CGFloat
    ) {
        Logger.debug("📱 Processing visible UITabBar...")
        
        do {
            let tabBarFrame = tabBar.convert(tabBar.bounds, to: window)
            
            guard tabBarFrame.width > 0, tabBarFrame.height > 0 else {
                Logger.warning("⚠️ TabBar has invalid frame, skipping")
                return
            }
            
            discovered["tab_bar"] = tabBarFrame
            Logger.info("   📍 FOUND [auto] tab_bar: \(tabBarFrame)")
            
            var itemIndex = 0
            for subview in tabBar.subviews {
                guard subview.superview != nil else { continue }
                guard subview.window != nil else { continue }
                
                let viewType = String(describing: type(of: subview))
                
                if viewType.contains("Button") {
                    let itemFrame = subview.convert(subview.bounds, to: window)
                    
                    if itemFrame.width > 0 &&
                       itemFrame.height > 0 &&
                       !subview.isHidden &&
                       subview.alpha > 0 {
                        
                        let itemId = "tab_item_\(itemIndex)"
                        discovered[itemId] = itemFrame
                        Logger.info("   📍 FOUND [auto] \(itemId): \(itemFrame)")
                        
                        if let label = findLabel(in: subview) {
                            let text = label.text ?? ""
                            if !text.isEmpty {
                                let labelId = "tab_\(text.lowercased().replacingOccurrences(of: " ", with: "_"))"
                                discovered[labelId] = itemFrame
                                Logger.info("   📍 FOUND [auto] \(labelId): \(itemFrame)")
                            }
                        }
                        
                        itemIndex += 1
                    }
                }
            }
            
            Logger.info("✅ TabBar captured: \(itemIndex) items detected")
            
        } catch {
            Logger.error("❌ Error during tab bar processing: \(error)")
            Logger.info("⏭️ Continuing without TabBar (screen will still be captured)")
        }
    }
    
    private func findLabel(in view: UIView) -> UILabel? {
        if let label = view as? UILabel {
            return label
        }
        
        for subview in view.subviews {
            if let label = findLabel(in: subview) {
                return label
            }
        }
        
        return nil
    }
    
    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar {
            guard tabBar.superview != nil else { return nil }
            return tabBar
        }
        
        for subview in view.subviews {
            if let tabBar = findTabBar(in: subview) {
                return tabBar
            }
        }
        
        return nil
    }
    
    // MARK: - Private Scanning Logic
    
    private func scanView(
        _ view: UIView,
        into discovered: inout [String: CGRect],
        pixelRatio: CGFloat,
        depth: Int = 0
    ) {
        if depth <= 5 {
            let viewType = String(describing: type(of: view))
            let identifier = view.accessibilityIdentifier ?? "nil"
            Logger.debug("      [\(depth)] \(viewType) - ID: \(identifier)")
        }
        
        var shouldProcessTag = !view.isHidden && view.alpha > 0
        
        if shouldProcessTag,
           let identifier = view.accessibilityIdentifier {
            
            // ✅ Handle both element and widget prefixes
            var cleanId: String? = nil
            
            if identifier.hasPrefix(elementPrefix) {
                cleanId = String(identifier.dropFirst(elementPrefix.count))
            } else if identifier.hasPrefix(widgetPrefix) {
                // ✅ Keep widget_ prefix in the ID
                cleanId = "widget_" + String(identifier.dropFirst(widgetPrefix.count))
            }
            
            if let cleanId = cleanId, discovered[cleanId] == nil {
                if let window = view.window {
                    let frameInWindow = view.convert(view.bounds, to: window)
                    
                    if frameInWindow.width > 0 && frameInWindow.height > 0 {
                        discovered[cleanId] = frameInWindow
                        Logger.info("      📍 FOUND [\(depth)] \(cleanId): \(frameInWindow)")
                    } else {
                        Logger.warning("      ⚠️ '\(cleanId)' has zero size frame — including anyway (fallback mode)")
                           
                        view.setNeedsLayout()
                        view.layoutIfNeeded()
                        let fallbackFrame = view.convert(view.bounds, to: window)
                        
                        discovered[cleanId] = fallbackFrame
                        Logger.info("      📍 FALLBACK [\(depth)] \(cleanId): \(fallbackFrame)")
                    }
                } else {
                    Logger.warning("      ⚠️ View '\(cleanId)' not in window, skipping")
                }
            }
        }
        
        for subview in view.subviews {
            scanView(subview, into: &discovered, pixelRatio: pixelRatio, depth: depth + 1)
        }
    }
    
    // MARK: - Async Element Waiting
    
    public func waitForElements(
        _ ids: [String],
        in rootView: UIView,
        timeout: TimeInterval = 2.0,
        requireAll: Bool = false
    ) async -> [String: CGRect] {
        let startTime = Date()
        var results: [String: CGRect] = [:]
        var pendingIds = ids
        
        for id in ids {
            if let frame = elementFrames[id], frame.width > 0, frame.height > 0 {
                results[id] = frame
                pendingIds.removeAll { $0 == id }
            }
        }
        
        if pendingIds.isEmpty {
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            Logger.debug("✅ All \(ids.count) elements found in cache (\(String(format: "%.0f", elapsed))ms)")
            return results
        }
        
        Logger.info("⏳ Waiting for \(pendingIds.count) elements (timeout: \(timeout)s)...")
        
        let shortTimeout = min(timeout, 0.5)
        
        if !requireAll {
            await withTaskGroup(of: (String, CGRect?).self) { group in
                for id in pendingIds {
                    group.addTask {
                        let frame = await self.waitForElement(
                            id,
                            in: rootView,
                            timeout: shortTimeout,
                            pollInterval: 0.05
                        )
                        return (id, frame)
                    }
                }
                
                var foundAny = false
                for await (id, frame) in group {
                    if let frame = frame {
                        results[id] = frame
                        if !foundAny {
                            foundAny = true
                            let elapsed = Date().timeIntervalSince(startTime) * 1000
                            Logger.info("⚡ First element '\(id)' found after \(String(format: "%.0f", elapsed))ms")
                        }
                    }
                }
            }
        } else {
            await withTaskGroup(of: (String, CGRect?).self) { group in
                for id in pendingIds {
                    group.addTask {
                        let frame = await self.waitForElement(
                            id,
                            in: rootView,
                            timeout: timeout,
                            pollInterval: 0.05
                        )
                        return (id, frame)
                    }
                }
                
                for await (id, frame) in group {
                    if let frame = frame {
                        results[id] = frame
                    }
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        let missing = ids.filter { results[$0] == nil }
        
        if missing.isEmpty {
            Logger.info("✅ All \(ids.count) elements found (\(String(format: "%.0f", elapsed))ms)")
        } else if requireAll {
            Logger.warning("⚠️ Found \(results.count)/\(ids.count) elements (\(String(format: "%.0f", elapsed))ms), missing: \(missing)")
        } else {
            Logger.info("✅ Found \(results.count)/\(ids.count) available elements (\(String(format: "%.0f", elapsed))ms)")
            if !missing.isEmpty {
                Logger.debug("   Missing (timed out after \(String(format: "%.1f", shortTimeout))s each): \(missing)")
            }
        }
        
        return results
    }
    
    public func waitForElement(
        _ id: String,
        in rootView: UIView,
        timeout: TimeInterval = 2.0,
        pollInterval: TimeInterval = 0.05,
        maxScans: Int? = nil
    ) async -> CGRect? {
        let deadline = Date().addingTimeInterval(timeout)
        let startTime = Date()
        var scanCount = 0
        var currentPollInterval = pollInterval
        
        let effectiveMaxScans = maxScans ?? Int(timeout / pollInterval) + 5
        
        while Date() < deadline && scanCount < effectiveMaxScans {
            if let frame = elementFrames[id], frame.width > 0, frame.height > 0 {
                let elapsed = Date().timeIntervalSince(startTime) * 1000
                Logger.debug("✅ Element '\(id)' found after \(String(format: "%.0f", elapsed))ms (\(scanCount) scans)")
                return frame
            }
            
            let _ = discoverElements(in: rootView, forceRefresh: true)
            scanCount += 1
            
            if let frame = elementFrames[id], frame.width > 0, frame.height > 0 {
                let elapsed = Date().timeIntervalSince(startTime) * 1000
                Logger.debug("✅ Element '\(id)' appeared after \(String(format: "%.0f", elapsed))ms (\(scanCount) scans)")
                return frame
            }
            
            if scanCount <= 3 {
                currentPollInterval = pollInterval
            } else if scanCount <= 10 {
                currentPollInterval = pollInterval * 2
            } else {
                currentPollInterval = min(pollInterval * 4, 0.2)
            }
            
            try? await Task.sleep(nanoseconds: UInt64(currentPollInterval * 1_000_000_000))
        }
        
        let elapsed = Date().timeIntervalSince(startTime) * 1000
        if scanCount >= effectiveMaxScans {
            Logger.warning("⏹️ Element '\(id)' not found after \(scanCount) scans (\(String(format: "%.0f", elapsed))ms) - scan limit reached")
        } else {
            Logger.warning("⏰ Element '\(id)' not found after \(String(format: "%.1f", timeout))s timeout (\(scanCount) scans)")
        }
        return nil
    }
}

// MARK: - Layout Change Observer

extension ElementRegistry {
    public func observeLayoutChanges(in view: UIView) {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
    }
    
    nonisolated public func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }
}
