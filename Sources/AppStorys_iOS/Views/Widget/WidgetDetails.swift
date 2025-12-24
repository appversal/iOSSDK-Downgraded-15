//
//  WidgetDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//

import Foundation

public struct WidgetDetails: Codable, Sendable {
    public let id: String?
    public let type: String?
    public let height: Int?
    public let width: Int?
    public let styling: WidgetStyling?
    public let widgetImages: [WidgetImage]?
    
    enum CodingKeys: String, CodingKey {
        case id, type, height, width, styling
        case widgetImages = "widget_images"
    }
}

public struct WidgetStyling: Codable, Sendable {
    public let topLeftRadius: String?
    public let topRightRadius: String?
    public let bottomLeftRadius: String?
    public let bottomRightRadius: String?
    public let topMargin: String?
    public let bottomMargin: String?
    public let leftMargin: String?
    public let rightMargin: String?
}

public struct WidgetImage: Codable, Sendable {
    public let id: String
    public let image: String?          // ✅ Made optional for Lottie support
    public let lottieData: String?     // ✅ NEW: Lottie animation URL
    public let link: String?
    public let order: Int
    
    enum CodingKeys: String, CodingKey {
        case id, image, link, order
        case lottieData = "lottie_data"  // ✅ Maps to snake_case from backend
    }
}

/// Represents a full widget campaign sent over WebSocket
public struct WidgetCampaign: Codable, Sendable, Identifiable {
    public let id: String
    public let campaignType: String
    public let clientId: String
    public let position: String?
    public let screen: String?
    public let isAll: Bool
    public let displayTrigger: Bool
    public let priority: Int
    public let createdAt: Date?
    public let details: WidgetDetails?

    enum CodingKeys: String, CodingKey {
        case id
        case campaignType = "campaign_type"
        case clientId = "client_id"
        case position
        case screen
        case isAll
        case displayTrigger = "display_trigger"
        case priority
        case createdAt
        case details
    }
    
    // MARK: - Date decoding
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        campaignType = try container.decodeIfPresent(String.self, forKey: .campaignType) ?? ""
        clientId = try container.decodeIfPresent(String.self, forKey: .clientId) ?? ""
        position = try container.decodeIfPresent(String.self, forKey: .position)
        screen = try container.decodeIfPresent(String.self, forKey: .screen)
        isAll = try container.decodeIfPresent(Bool.self, forKey: .isAll) ?? false
        displayTrigger = try container.decodeIfPresent(Bool.self, forKey: .displayTrigger) ?? false
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        details = try container.decodeIfPresent(WidgetDetails.self, forKey: .details)
        
        // ✅ Handle ISO8601 date string safely
        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString)
        } else {
            createdAt = nil
        }
    }
}
