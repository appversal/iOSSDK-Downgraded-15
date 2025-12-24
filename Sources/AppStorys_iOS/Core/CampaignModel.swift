//
//  CampaignModel.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//


//
//  CampaignModel.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 31/10/25.
//

import Foundation

public struct CampaignModel: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let campaignType: String
    public let clientId: String
    public let position: String?
    public let details: CampaignDetails
    public let screen: String?
    public let displayTrigger: Bool?
    public let triggerEvent: String?
    public let isAll: Bool?
    public let isTesting: Bool?
    public let priority: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case campaignType = "campaign_type"
        case clientId = "client_id"
        case position, details, screen
        case displayTrigger = "display_trigger"
        case triggerEvent = "trigger_event"
        case isAll, isTesting, priority
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        campaignType = try container.decode(String.self, forKey: .campaignType)
        clientId = try container.decode(String.self, forKey: .clientId)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        screen = try container.decodeIfPresent(String.self, forKey: .screen)
        displayTrigger = try container.decodeIfPresent(Bool.self, forKey: .displayTrigger)
        triggerEvent = try container.decodeIfPresent(String.self, forKey: .triggerEvent)
        isAll = try container.decodeIfPresent(Bool.self, forKey: .isAll)
        isTesting = try container.decodeIfPresent(Bool.self, forKey: .isTesting)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        
        // Decode details based on campaign type
        switch campaignType {
        case "PIP":
            let pipDetails = try container.decode(PipDetails.self, forKey: .details)
            details = .pip(pipDetails)
            Logger.debug("Decoded PIP campaign")
        case "BAN":
            let bannerDetails = try container.decode(BannerDetails.self, forKey: .details)
            details = .banner(bannerDetails)
            Logger.debug("Decoded BAN campaign")
        case "FLT":
            let floaterDetails = try container.decode(FloaterDetails.self, forKey: .details)
            details = .floater(floaterDetails)
            Logger.debug("Decoded FLT campaign")
        case "CSAT":
            let csatDetails = try container.decode(CsatDetails.self, forKey: .details)
            details = .csat(csatDetails)
            Logger.debug("Decoded CSAT campaign")
        case "SUR":
            let surveyDetails = try container.decode(SurveyDetails.self, forKey: .details)
            details = .survey(surveyDetails)
            Logger.debug("Decoded SUR campaign")
        case "BTS":
            let btsDetails = try container.decode(BottomSheetDetails.self, forKey: .details)
            details = .bottomSheet(btsDetails)
            Logger.debug("Decoded BTS campaign")
        case "WID":
            let widgetDetails = try container.decode(WidgetDetails.self, forKey: .details)
            details = .widget(widgetDetails)
            Logger.debug("Decoded WID campaign with \(widgetDetails.widgetImages?.count ?? 0) images")
        case "STR":
            let storyDetails = try container.decode([StoryDetails].self, forKey: .details)
            details = .stories(storyDetails)
            Logger.debug("Decoded STR campaign with \(storyDetails.count) stories")
        case "MOD":
            let modalDetails = try container.decode(ModalDetails.self, forKey: .details)
            details = .modal(modalDetails)
            Logger.debug("Decoded MOD campaign")
        case "TTP":
            let tooltipDetails = try container.decode(TooltipDetails.self, forKey: .details)
            details = .tooltip(tooltipDetails)  // ← Assign to details property
            Logger.debug("Decoded TTP campaign with \(tooltipDetails.tooltips.count) steps")
        case "SCRT":
            let scratchDetails = try container.decode(ScratchCardDetails.self, forKey: .details)
            details = .scratchCard(scratchDetails)
            Logger.debug("Decoded SCRT campaign")
        case "MIL":
            let milestoneDetails = try container.decode(MilestoneDetails.self, forKey: .details)
            details = .milestone(milestoneDetails)
            Logger.debug("Decoded MIL campaign")
        default:
            Logger.warning("Unknown campaign type: \(campaignType)")
            details = .unknown
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(campaignType, forKey: .campaignType)
        try container.encode(clientId, forKey: .clientId)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(screen, forKey: .screen)
        try container.encodeIfPresent(displayTrigger, forKey: .displayTrigger)
        try container.encodeIfPresent(triggerEvent, forKey: .triggerEvent)
        try container.encodeIfPresent(isAll, forKey: .isAll)
        try container.encodeIfPresent(isTesting, forKey: .isTesting)
        try container.encodeIfPresent(priority, forKey: .priority)
        
        // Encode details
        switch details {
        case .pip(let pipDetails):
            try container.encode(pipDetails, forKey: .details)
        case .banner(let bannerDetails):
            try container.encode(bannerDetails, forKey: .details)
        case .floater(let floaterDetails):
            try container.encode(floaterDetails, forKey: .details)
        case .csat(let csatDetails):
            try container.encode(csatDetails, forKey: .details)
        case .survey(let surveyDetails):
            try container.encode(surveyDetails, forKey: .details)
        case .bottomSheet(let btsDetails):
            try container.encode(btsDetails, forKey: .details)
        case .widget(let widgetDetails):
            try container.encode(widgetDetails, forKey: .details)
        case .tooltip(let tooltipDetails):
            try container.encode(tooltipDetails, forKey: .details)
        case .modal(let modalDetails):
            try container.encode(modalDetails, forKey: .details)
        case .stories(let storyDetails):
            try container.encode(storyDetails, forKey: .details)
        case .reel(let reelDetails):
            try container.encode(reelDetails, forKey: .details)
        case .scratchCard(let scratchDetails):
            try container.encode(scratchDetails, forKey: .details)
        case .milestone(let milestoneDetails):
            try container.encode(milestoneDetails, forKey: .details)
        case .unknown:
            break
        }
    }
    
    public static func == (lhs: CampaignModel, rhs: CampaignModel) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Campaign Details Enum
public enum CampaignDetails: Sendable, Equatable {
    case banner(BannerDetails)
    case floater(FloaterDetails)
    case pip(PipDetails)
    case csat(CsatDetails)
    case survey(SurveyDetails)
    case widget(WidgetDetails)
    case bottomSheet(BottomSheetDetails)
    case tooltip(TooltipDetails)
    case modal(ModalDetails)
    case stories([StoryDetails])
    case reel(ReelDetails)
    case scratchCard(ScratchCardDetails)
    case milestone(MilestoneDetails)
    case unknown
    
    // ✅ FIXED: Compare actual associated values
    // Since CampaignModel.== compares IDs, we can use a simple discriminant check here
    // This is safe because two campaigns with different IDs won't reach this comparison
    public static func == (lhs: CampaignDetails, rhs: CampaignDetails) -> Bool {
        switch (lhs, rhs) {
        case (.banner, .banner),
            (.floater, .floater),
            (.pip, .pip),
            (.csat, .csat),
            (.survey, .survey),
            (.widget, .widget),
            (.bottomSheet, .bottomSheet),
            (.tooltip, .tooltip),
            (.modal, .modal),
            (.stories, .stories),
            (.reel, .reel),
            (.scratchCard, .scratchCard),
            (.milestone, .milestone),
            (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}
