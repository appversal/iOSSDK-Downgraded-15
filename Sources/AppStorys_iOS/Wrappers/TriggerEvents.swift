//
//  TriggerEvents.swift
//  AppStorys_iOS
//
//  ✅ AUTO-WAITS: All methods wait for SDK initialization
//  ✅ THREAD-SAFE: Properly queued operations
//  ✅ DEVICE CONTEXT: Automatically includes device attributes for custom events
//

import SwiftUI

// MARK: - Main Public API Extension
public extension AppStorys {
    
    // MARK: - Event Triggering (Static Methods)
    
    /// Triggers a custom AppStorys event with full device context
    /// ✅ Automatically waits for SDK to be ready
    /// ✅ Includes device attributes (platform, OS version, screen size, etc.)
    /// ✅ Merges user attributes from setUserAttributes()
    ///
    /// - Parameters:
    ///   - eventType: Name of the event (e.g., "Loan Approved", "Purchase Completed")
    ///   - metadata: Optional additional data to attach to the event
    ///
    /// Example:
    /// ```swift
    /// Button("Complete Purchase") {
    ///     AppStorys.triggerEvent("Purchase Completed", metadata: [
    ///         "amount": 99.99,
    ///         "currency": "USD"
    ///     ])
    /// }
    /// ```
    ///
    /// The backend will receive:
    /// ```json
    /// {
    ///   "event": "Purchase Completed",
    ///   "metadata": {
    ///     "amount": 99.99,
    ///     "currency": "USD",
    ///     "platform": "ios",
    ///     "model": "iPhone15,2",
    ///     "os_version": "17.2",
    ///     "screen_width_px": 1179,
    ///     "orientation": "portrait",
    ///     // ... other device attributes
    ///     // ... user attributes from setUserAttributes()
    ///   }
    /// }
    /// ```
    static func triggerEvent(
        _ eventType: String,
        metadata: [String: Any]? = nil
    ) {
        Task {
            // ✅ Auto-wait for initialization
            await shared.waitForInitialization()
            
            await shared.trackEvents(
                eventType: eventType,
                campaignId: " ", // Space indicates no specific campaign
                metadata: metadata
            )
        }
    }
    
    /// Triggers a campaign-specific event with full device context
    /// ✅ Automatically waits for SDK to be ready
    /// ✅ Includes device attributes + user attributes
    ///
    /// - Parameters:
    ///   - eventType: Name of the event
    ///   - campaignId: ID of the associated campaign
    ///   - metadata: Optional additional data
    ///
    /// Example:
    /// ```swift
    /// AppStorys.triggerEvent(
    ///     "Button Clicked",
    ///     campaignId: "camp_123",
    ///     metadata: ["button_label": "Get Started"]
    /// )
    /// ```
    static func triggerEvent(
        _ eventType: String,
        campaignId: String,
        metadata: [String: Any]? = nil
    ) {
        Task {
            // ✅ Auto-wait for initialization
            await shared.waitForInitialization()
            
            await shared.trackEvents(
                eventType: eventType,
                campaignId: campaignId,
                metadata: metadata
            )
        }
    }
}
