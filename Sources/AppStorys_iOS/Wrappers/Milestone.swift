//
//  Milestone.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 09/12/25.
//

import SwiftUI

public extension AppStorys {
    
    /// Display a Milestone campaign inline at a specific position
    ///
    /// Usage:
    /// ```swift
    /// AppStorys.Milestone(position: "home_header")
    /// ```
    struct Milestone: View {
        @ObservedObject private var sdk = AppStorys.shared
        let position: String
        
        public init(position: String) {
            self.position = position
        }
        
        public var body: some View {
            // Find a MIL campaign that matches the requested position
            if let campaign = sdk.milestoneCampaigns.first(where: { $0.position == position }),
               case let .milestone(details) = campaign.details {
                
                MilestoneView(
                    campaignId: campaign.id,
                    details: details
                )
                .id(campaign.id) // Force refresh if campaign changes
                .transition(.opacity)
                
            } else {
                // Returns nothing if no campaign matches this position
                EmptyView()
            }
        }
    }
}
