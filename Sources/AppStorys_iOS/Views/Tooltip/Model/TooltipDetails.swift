//
//  TooltipDetails.swift
//  AppStorys_iOS
//
//  Tooltip campaign structure with styling and positioning
//  ✅ FIXED: Renamed TooltipArrow to TooltipArrowConfig to avoid conflict
//  ✅ ADDED: Convenience initializer for filtered tooltips (graceful degradation)
//

import Foundation

public struct TooltipDetails: Codable, Sendable {
    public let id: String
    public let campaign: String
    public let name: String
    public let screenId: String
    public let tooltips: [TooltipStep]
    public let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case campaign
        case name
        case screenId
        case tooltips
        case createdAt = "created_at"
    }
    
    // ✅ NEW: Convenience initializer for filtered tooltips
    /// Create TooltipDetails with filtered tooltip steps
    /// Used when presenting partial tooltips (graceful degradation)
    /// - Parameters:
    ///   - original: Original TooltipDetails with all metadata
    ///   - filteredTooltips: Subset of tooltips that have available targets
    public init(from original: TooltipDetails, filteredTooltips: [TooltipStep]) {
        self.id = original.id
        self.campaign = original.campaign
        self.name = original.name
        self.screenId = original.screenId
        self.tooltips = filteredTooltips  // ✅ Only available steps
        self.createdAt = original.createdAt
    }
}

public struct TooltipStep: Codable, Sendable, Identifiable {
    public let id: String
    public let target: String
    public let type: String
    public let url: String?
    public let position: String
    public let order: Int
    public let clickAction: String
    public let triggerType: String
    public let deepLinkUrl: String?
    public let eventName: String?
    public let link: String?
    public let styling: TooltipStyling
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case target
        case type
        case url
        case position
        case order
        case clickAction
        case triggerType
        case deepLinkUrl
        case eventName
        case link
        case styling
    }
}

public struct TooltipStyling: Codable, Sendable {
    public let backgroundColor: String
    public let closeButton: Bool
    public let enableBackdrop: Bool
    public let highlightPadding: String
    public let highlightRadius: String
    public let spacing: TooltipSpacing
    public let tooltipArrow: TooltipArrowConfig  // ✅ RENAMED from TooltipArrow
    public let tooltipDimensions: TooltipDimensions
}

public struct TooltipSpacing: Codable, Sendable {
    public let paddingTop: String
    public let paddingBottom: String
    public let paddingLeft: String
    public let paddingRight: String
}

// ✅ RENAMED: TooltipArrow → TooltipArrowConfig
public struct TooltipArrowConfig: Codable, Sendable {
    public let arrowWidth: String
    public let arrowHeight: String
}

public struct TooltipDimensions: Codable, Sendable {
    public let width: String
    public let height: String
    public let cornerRadius: String
}
