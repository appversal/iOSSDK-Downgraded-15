//
//  TooltipManager.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Safe initialization guard against premature SDK access
//

import SwiftUI
import UIKit

@MainActor
public class TooltipManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published public var currentStep: Int = 0
    @Published public var isPresenting: Bool = false
    
    // MARK: - Dependencies
    
    private let elementRegistry: ElementRegistry
    private weak var sdk: AppStorys?
    
    // ✅ NEW: Initialization state guard
    private var isInitialized: Bool = false
    
    // MARK: - State
    
    private var currentCampaign: CampaignModel?
    private var tooltipDetails: TooltipDetails?
    private var presentedOnScreen: String?
    private var cachedFrames: [String: CGRect] = [:]
    
    // MARK: - Initialization
    
    public init(elementRegistry: ElementRegistry) {
        self.elementRegistry = elementRegistry
        Logger.debug("🔧 TooltipManager created (not yet initialized)")
    }
    
    /// Set SDK reference for event tracking
    /// ✅ CRITICAL: Must be called before any presentation attempts
    func setSDK(_ sdk: AppStorys) {
        self.sdk = sdk
        self.isInitialized = true
        Logger.info("✅ TooltipManager fully initialized with SDK reference")
    }
    
    // MARK: - Initialization Guard
    
    /// ✅ NEW: Safely check if manager is ready to present tooltips
    private var canPresent: Bool {
        guard isInitialized else {
            Logger.warning("⚠️ TooltipManager not initialized - SDK reference missing")
            return false
        }
        guard sdk != nil else {
            Logger.warning("⚠️ TooltipManager SDK reference is nil")
            return false
        }
        return true
    }
    
    // MARK: - Presentation
    
    /// Present tooltip campaign
    /// ✅ SAFE: Now checks initialization before proceeding
    @discardableResult
    public func present(campaign: CampaignModel, rootView: UIView) -> PresentationResult {
        // ✅ CRITICAL: Check initialization first
        guard canPresent else {
            Logger.error("❌ Cannot present tooltip - manager not initialized")
            return .failure(.managerNotInitialized)
        }
        
        guard case .tooltip(let details) = campaign.details else {
            return .failure(.invalidCampaign)
        }
        
        guard !isPresenting else {
            Logger.warning("⚠️ Tooltip already presenting")
            return .failure(.alreadyPresenting)
        }
        
        // Discover elements
        let elements = elementRegistry.discoverElements(in: rootView, forceRefresh: true)
        
        // Separate available vs missing steps
        var availableSteps: [(step: TooltipStep, frame: CGRect)] = []
        var missingSteps: [String] = []
        
        for tooltip in details.tooltips {
            if let frame = elements[tooltip.target],
               frame.width > 0,
               frame.height > 0 {
                availableSteps.append((tooltip, frame))
                cachedFrames[tooltip.target] = frame
            } else {
                missingSteps.append(tooltip.target)
            }
        }
        
        guard !availableSteps.isEmpty else {
            Logger.error("❌ No tooltip targets found: \(missingSteps)")
            return .failure(.noTargetsFound(missingSteps))
        }
        
        if !missingSteps.isEmpty {
            Logger.warning("⚠️ Skipping \(missingSteps.count) unavailable steps: \(missingSteps)")
        }
        
        // Store only available steps
        self.currentCampaign = campaign
        self.tooltipDetails = TooltipDetails(
            from: details,
            filteredTooltips: availableSteps.map(\.step)
        )
        self.currentStep = 0
        self.isPresenting = true
        self.presentedOnScreen = campaign.screen
        
        Logger.info("✅ Presenting tooltip with \(availableSteps.count)/\(details.tooltips.count) steps")
        
        trackEvent(type: "viewed", metadata: [
            "step": 1,
            "available_steps": availableSteps.count,
            "missing_steps": missingSteps.count,
            "skipped_targets": missingSteps.joined(separator: ",")
        ])
        
        return .success(availableSteps.count)
    }

    public func presentWithWaiting(
        campaign: CampaignModel,
        rootView: UIView,
        elementTimeout: TimeInterval = 1.5
    ) async -> PresentationResult {
        // ✅ CRITICAL: Check initialization first
        guard canPresent else {
            Logger.error("❌ Cannot present tooltip - manager not initialized")
            return .failure(.managerNotInitialized)
        }
        
        guard case .tooltip(let details) = campaign.details else {
            return .failure(.invalidCampaign)
        }
        
        guard !isPresenting else {
            Logger.warning("⚠️ Tooltip already presenting")
            return .failure(.alreadyPresenting)
        }
        
        Logger.info("⏳ Waiting for tooltip elements (timeout: \(elementTimeout)s)...")
        
        let targetIds = details.tooltips.map { $0.target }
        let foundElements = await elementRegistry.waitForElements(
            targetIds,
            in: rootView,
            timeout: elementTimeout,
            requireAll: false
        )
        
        // Separate available vs missing
        var availableSteps: [(step: TooltipStep, frame: CGRect)] = []
        var missingSteps: [String] = []
        
        for tooltip in details.tooltips {
            if let frame = foundElements[tooltip.target] {
                availableSteps.append((tooltip, frame))
                cachedFrames[tooltip.target] = frame
            } else {
                missingSteps.append(tooltip.target)
            }
        }
        
        guard !availableSteps.isEmpty else {
            Logger.error("❌ No tooltip targets found after waiting: \(missingSteps)")
            return .failure(.noTargetsFound(missingSteps))
        }
        
        if !missingSteps.isEmpty {
            Logger.warning("⚠️ Skipping \(missingSteps.count) unavailable steps: \(missingSteps)")
        }
        
        // Store only available steps
        self.currentCampaign = campaign
        self.tooltipDetails = TooltipDetails(
            from: details,
            filteredTooltips: availableSteps.map(\.step)
        )
        self.currentStep = 0
        self.isPresenting = true
        self.presentedOnScreen = campaign.screen
        
        Logger.info("✅ Presenting tooltip with \(availableSteps.count)/\(details.tooltips.count) steps")
        
        trackEvent(type: "viewed", metadata: [
            "step": 1,
            "available_steps": availableSteps.count,
            "missing_steps": missingSteps.count,
            "wait_duration": elementTimeout
        ])
        
        return .success(availableSteps.count)
    }
    
    // Return type for better error handling
    public enum PresentationResult {
        case success(Int)
        case failure(PresentationError)
        
        public enum PresentationError {
            case invalidCampaign
            case noTargetsFound([String])
            case alreadyPresenting
            case managerNotInitialized  // ✅ NEW: Handle uninitialized state
        }
    }
    
    public func validateScreen(_ currentScreen: String) -> Bool {
        guard let presentedScreen = presentedOnScreen else {
            return true
        }
        
        let matches = presentedScreen.lowercased() == currentScreen.lowercased()
        
        if !matches {
            Logger.warning("⚠️ Tooltip screen mismatch: expected '\(presentedScreen)' but on '\(currentScreen)'")
            dismiss()
        }
        
        return matches
    }
    
    // MARK: - Navigation
    
    public func nextStep() {
        guard canPresent else { return }
        guard let details = tooltipDetails else { return }
        
        if currentStep < details.tooltips.count - 1 {
            currentStep += 1
            Logger.debug("➡️ Moving to tooltip step \(currentStep + 1)")
            
            trackEvent(
                type: "viewed",
                metadata: ["step": currentStep + 1]
            )
        } else {
            trackEvent(
                type: "completed",
                metadata: ["total_steps": details.tooltips.count]
            )
            dismiss()
        }
    }
    
    public func previousStep() {
        guard canPresent else { return }
        
        if currentStep > 0 {
            currentStep -= 1
            Logger.debug("⬅️ Moving to tooltip step \(currentStep + 1)")
            
            trackEvent(
                type: "viewed",
                metadata: ["step": currentStep + 1]
            )
        }
    }
    
    public func goToStep(_ step: Int) {
        guard canPresent else { return }
        guard let details = tooltipDetails,
              step >= 0,
              step < details.tooltips.count else {
            return
        }
        
        currentStep = step
        Logger.debug("🎯 Jumped to tooltip step \(step + 1)")
        
        trackEvent(
            type: "viewed",
            metadata: ["step": step + 1]
        )
    }
    
    /// Dismiss tooltip
    /// ✅ SAFE: Can dismiss even if not initialized (cleanup scenario)
    public func dismiss() {
        guard isPresenting else { return }
        
        isPresenting = false
        
        // Only track if initialized
        if canPresent {
            trackEvent(
                type: "dismissed",
                metadata: [
                    "step": currentStep + 1,
                    "reason": "user_action"
                ]
            )
        }
        
        // Reset state
        currentStep = 0
        currentCampaign = nil
        tooltipDetails = nil
        presentedOnScreen = nil
        cachedFrames.removeAll()
        
        Logger.info("📌 Dismissed tooltip")
    }
    
    // MARK: - Screen Validation
    
    public func shouldDisplay(forScreen screenName: String) -> Bool {
        guard isPresenting else { return false }
        
        guard let presentedScreen = presentedOnScreen else {
            return true
        }
        
        let matches = presentedScreen.lowercased() == screenName.lowercased()
        
        if !matches {
            Logger.warning("⚠️ Tooltip screen mismatch: expected '\(presentedScreen)' but on '\(screenName)'")
            dismiss()
        }
        
        return matches
    }
    
    public var currentScreen: String? {
        return presentedOnScreen
    }
    
    // MARK: - Accessors
    
    public func getCurrentTooltip() -> (campaign: CampaignModel, step: TooltipStep, frame: CGRect)? {
        guard canPresent else {
            Logger.warning("⚠️ Cannot get tooltip - manager not initialized")
            return nil
        }
        
        guard let campaign = currentCampaign,
              let details = tooltipDetails,
              currentStep < details.tooltips.count else {
            Logger.warning("⚠️ No tooltip data available")
            return nil
        }
        
        let tooltip = details.tooltips[currentStep]
        
        guard let frame = cachedFrames[tooltip.target] else {
            Logger.error("❌ Cached frame not found for '\(tooltip.target)'")
            Logger.error("   Available cached frames: \(cachedFrames.keys.joined(separator: ", "))")
            return nil
        }
        
        guard frame.width > 0 && frame.height > 0 else {
            Logger.error("❌ Invalid cached frame for '\(tooltip.target)': \(frame)")
            return nil
        }
        
        Logger.debug("✅ Using cached frame for '\(tooltip.target)': \(frame)")
        return (campaign, tooltip, frame)
    }
    
    public func hasTarget(_ targetId: String) -> Bool {
        return elementRegistry.hasElement(targetId)
    }
    
    public var totalSteps: Int {
        return tooltipDetails?.tooltips.count ?? 0
    }
    
    public var isFirstStep: Bool {
        return currentStep == 0
    }
    
    public var isLastStep: Bool {
        return currentStep == totalSteps - 1
    }
    
    // MARK: - Debug Helpers
    
    public func debugState() {
        Logger.debug("=== TooltipManager State ===")
        Logger.debug("isInitialized: \(isInitialized)")
        Logger.debug("isPresenting: \(isPresenting)")
        Logger.debug("currentStep: \(currentStep)/\(totalSteps)")
        Logger.debug("presentedOnScreen: \(presentedOnScreen ?? "nil")")
        Logger.debug("cachedFrames: \(cachedFrames.count)")
        for (id, frame) in cachedFrames {
            Logger.debug("  \(id): \(frame)")
        }
        Logger.debug("========================")
    }
    
    // MARK: - Event Tracking
    
    /// ✅ SAFE: Only tracks if SDK is available
    private func trackEvent(type: String, metadata: [String: Any]? = nil) {
        guard canPresent else {
            Logger.debug("⏭ Skipping event tracking - SDK not available")
            return
        }
        
        guard let campaign = currentCampaign else { return }
        
        Task {
            await sdk?.trackEvents(
                eventType: type,
                campaignId: campaign.id,
                metadata: metadata
            )
        }
    }
}

// MARK: - Tooltip Step Extensions

extension TooltipStep {
    var highlightPadding: CGFloat {
        CGFloat(Double(styling.highlightPadding) ?? 6)
    }
    
    var highlightRadius: CGFloat {
        CGFloat(Double(styling.highlightRadius) ?? 20)
    }
    
    var tooltipWidth: CGFloat {
        CGFloat(Double(styling.tooltipDimensions.width) ?? 200)
    }
    
    var tooltipHeight: CGFloat {
        CGFloat(Double(styling.tooltipDimensions.height) ?? 200)
    }
    
    var tooltipCornerRadius: CGFloat {
        CGFloat(Double(styling.tooltipDimensions.cornerRadius) ?? 20)
    }
    
    var arrowWidth: CGFloat {
        CGFloat(Double(styling.tooltipArrow.arrowWidth) ?? 10)
    }
    
    var arrowHeight: CGFloat {
        CGFloat(Double(styling.tooltipArrow.arrowHeight) ?? 10)
    }
    
    var backgroundColor: Color {
        Color(hex: styling.backgroundColor) ?? .clear
    }
}
