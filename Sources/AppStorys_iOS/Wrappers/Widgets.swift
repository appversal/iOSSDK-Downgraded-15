//
//  WidgetSlot.swift
//  AppStorys_iOS
//
//  ✅ ENHANCED: Position-based widget system with capture tagging
//

import SwiftUI

public extension AppStorys {
    
    // MARK: - Single Widget at Position
    
    /// Display a widget at a specific position
    /// - Parameter position: The position identifier that matches backend campaign.position
    ///
    /// Example:
    /// ```swift
    /// AppStorys.Widget(position: "top_banner")
    ///     .captureAppStorysWidgetTag("top_banner")
    /// ```
    public struct Widget: View {
        @ObservedObject private var sdk = AppStorys.shared
        private let position: String
        
        public init(position: String) {
            self.position = position
        }
        
        public var body: some View {
            // Find widget campaign matching this position
            if let campaign = sdk.widgetCampaigns.first(where: { $0.position == position }),
               case .widget(let widgetDetails) = campaign.details {
                WidgetView(
                    campaignId: campaign.id,
                    details: widgetDetails
                )
                .id(campaign.id)
            }
        }
    }
    
    // MARK: - All Widgets Container
    
    /// Display widget campaigns at specific positions
    ///
    /// **Position Discovery Flow:**
    /// 1. Tag positions in your app with `.captureAppStorysWidgetTag("position_name")`
    /// 2. Capture screen sends available positions to dashboard
    /// 3. Dashboard: Assign widget campaigns to specific positions
    /// 4. Backend sends campaigns with matching position
    /// 5. Widget displays at tagged location
    ///
    /// Usage:
    /// ```swift
    /// // Show all widgets (no filtering)
    /// AppStorys.Widgets()
    ///
    /// // Show widget at specific position (with position tagging for discovery)
    /// AppStorys.Widgets(position: "first_Widget")
    ///
    /// // Or tag separately for position discovery
    /// AppStorys.Widgets()
    ///     .captureAppStorysWidgetTag("first_Widget")
    /// ```
    public struct Widgets: View {
        @ObservedObject private var sdk = AppStorys.shared
        private let position: String?
        
        public init() {
            self.position = nil
        }

        public init(position: String) {
            self.position = position
        }
        
        public var body: some View {
            VStack(spacing: 0) {
                if let position = position {
                    filteredWidgetView(for: position)
                } else {
                    allWidgetsView
                }
            }
            // ✅ CRITICAL FIX: Force SwiftUI to recreate widget when campaign changes
            .id(widgetIdentity) // ← Add this
        }
        
        // ✅ Stable identity that includes both campaign ID and screen
        private var widgetIdentity: String {
            if let position = position {
                let fullPosition = "widget_\(position)"
                if let campaign = sdk.widgetCampaigns.first(where: { $0.position == fullPosition }) {
                    return "\(sdk.currentScreen ?? "unknown")_\(campaign.id)"
                }
                return "\(sdk.currentScreen ?? "unknown")_\(fullPosition)_empty"
            } else {
                if let campaign = sdk.widgetCampaigns.first(where: { $0.position == nil || $0.position!.isEmpty }) {
                    return "\(sdk.currentScreen ?? "unknown")_\(campaign.id)"
                }
                return "\(sdk.currentScreen ?? "unknown")_default_empty"
            }
        }
        
        @ViewBuilder
        private func filteredWidgetView(for position: String) -> some View {
            let fullPosition = "widget_\(position)"
            
            if let campaign = sdk.widgetCampaigns.first(where: { campaign in
                guard campaign.screen == sdk.currentScreen else { return false }   // ← CRITICAL FIX
                guard let campaignPosition = campaign.position, !campaignPosition.isEmpty else { return false }
                
                return campaignPosition == fullPosition || campaignPosition == position
            }), case .widget(let widgetDetails) = campaign.details {
                
                WidgetView(
                    campaignId: campaign.id,
                    details: widgetDetails
                )
                .id("\(campaign.id)_\(sdk.currentScreen ?? "")")
                
            } else {
                EmptyView()
            }
        }

        @ViewBuilder
        private var allWidgetsView: some View {
            let defaultWidgets = sdk.widgetCampaigns.filter { campaign in
                guard campaign.screen == sdk.currentScreen else { return false }
                if let position = campaign.position, !position.isEmpty {
                    return false
                } else {
                    return true
                }
            }
            
            if let campaign = defaultWidgets.first {
                if case .widget(let widgetDetails) = campaign.details {
                    WidgetView(
                        campaignId: campaign.id,
                        details: widgetDetails
                    )
                    .id("\(campaign.id)_\(sdk.currentScreen ?? "")") // ✅ Ensure unique ID per screen
                } else {
                    EmptyView()
                }
            } else {
                EmptyView()
            }
        }
    }
}
