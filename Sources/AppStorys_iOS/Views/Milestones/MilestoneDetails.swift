//
//  MilestoneDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/12/25.
//

import Foundation

public struct MilestoneDetails: Codable, Sendable {
    public let id: String
    public let name: String?
    public let displayType: String? // e.g., "progressBar"
    public let headerImage: String?
    public let progressLogic: String?
    public let content: MilestoneContent?
    public let styling: MilestoneStyling?
    public let milestoneItems: [MilestoneItem]?
    public let milestoneRewards: [MilestoneReward]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, displayType, headerImage, progressLogic, content, styling
        case milestoneItems = "milestone_items"
        case milestoneRewards = "milestone_rewards"
    }
}

public struct MilestoneContent: Codable, Sendable {
    public let title: String?
    public let stepCounterLabel: String?
    public let completionLabel: String?
}

public struct MilestoneItem: Codable, Sendable {
    public let id: String
    public let label: String?
    public let order: Int
    public let pbImage: String?
    public let pbTitle: String?
    public let triggerEvents: [MilestoneTriggerEvent]?
    
    enum CodingKeys: String, CodingKey {
        case id, label, order, pbImage, pbTitle, triggerEvents
    }
}

public struct MilestoneTriggerEvent: Codable, Sendable {
    public let condition: String? // "once", "cumulative"
    public let eventName: String?
    public let progressLogic: TriggerProgressLogic?
}

public struct TriggerProgressLogic: Codable, Sendable {
    public let type: String? // "fixed", "dynamic"
    public let value: Double?
    public let path: String?
    
    // Custom decoding to handle Int/Double mismatch safely
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        
        if let doubleVal = try? container.decode(Double.self, forKey: .value) {
            value = doubleVal
        } else if let intVal = try? container.decode(Int.self, forKey: .value) {
            value = Double(intVal)
        } else {
            value = nil
        }
    }
}

public struct MilestoneReward: Codable, Sendable {
    public let id: String
    public let rewardText: String?
    public let rewardImage: String?
    public let rewardCTA: String?
    public let ctaUrl: String?
}

public struct MilestoneStyling: Codable, Sendable {
    public let activeColor: String?
    public let completedColor: String?
    public let inactiveColor: String?
    public let containerBackgroundColor: String?
    public let containerBorderColor: String?
    public let containerCornerRadius: Double?
    public let containerBorderWidth: Double?
    public let titleColor: String?
    public let labelColor: String?
    public let counterTextColor: String?
    public let headerIconColor: String?
    public let stripeColor: String?
    public let progressBarHeight: StringOrInt   // <–– correct

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        activeColor = try container.decodeIfPresent(String.self, forKey: .activeColor)
        completedColor = try container.decodeIfPresent(String.self, forKey: .completedColor)
        inactiveColor = try container.decodeIfPresent(String.self, forKey: .inactiveColor)
        containerBackgroundColor = try container.decodeIfPresent(String.self, forKey: .containerBackgroundColor)
        containerBorderColor = try container.decodeIfPresent(String.self, forKey: .containerBorderColor)
        titleColor = try container.decodeIfPresent(String.self, forKey: .titleColor)
        labelColor = try container.decodeIfPresent(String.self, forKey: .labelColor)
        counterTextColor = try container.decodeIfPresent(String.self, forKey: .counterTextColor)
        headerIconColor = try container.decodeIfPresent(String.self, forKey: .headerIconColor)
        stripeColor = try container.decodeIfPresent(String.self, forKey: .stripeColor)

        // corner radius
        if let radius = try? container.decode(Double.self, forKey: .containerCornerRadius) {
            containerCornerRadius = radius
        } else if let str = try? container.decode(String.self, forKey: .containerCornerRadius) {
            containerCornerRadius = Double(str)
        } else {
            containerCornerRadius = 24
        }

        // border width
        if let width = try? container.decode(Double.self, forKey: .containerBorderWidth) {
            containerBorderWidth = width
        } else if let str = try? container.decode(String.self, forKey: .containerBorderWidth) {
            containerBorderWidth = Double(str)
        } else {
            containerBorderWidth = 0
        }

        // ✅ Decode progressBarHeight (String or Int)
        progressBarHeight = try container.decodeIfPresent(StringOrInt.self, forKey: .progressBarHeight) ?? .int(4)
    }
}

