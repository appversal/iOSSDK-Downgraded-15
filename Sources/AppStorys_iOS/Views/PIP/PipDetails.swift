//
//  PipDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//


import Foundation

public struct PipDetails: Codable, Sendable {
    public let id: String?
    public let position: String?
    public let smallVideo: String?
    public let largeVideo: String?
    public let height: Int?
    public let width: Int?
    public let link: String?
    public let campaign: String?
    public let buttonText: String?
    public let screen: String?
    public let styling: PipStyling?

    enum CodingKeys: String, CodingKey {
        case id, position, height, width, link, campaign, screen, styling
        case smallVideo = "small_video"
        case largeVideo = "large_video"
        case buttonText = "button_text"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        smallVideo = try container.decodeIfPresent(String.self, forKey: .smallVideo)
        largeVideo = try container.decodeIfPresent(String.self, forKey: .largeVideo)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        campaign = try container.decodeIfPresent(String.self, forKey: .campaign)
        buttonText = try container.decodeIfPresent(String.self, forKey: .buttonText)
        styling = try container.decodeIfPresent(PipStyling.self, forKey: .styling)
        
        if let screenInt = try? container.decode(Int.self, forKey: .screen) {
            screen = String(screenInt)
        } else {
            screen = try container.decodeIfPresent(String.self, forKey: .screen)
        }
    }
}

public struct PipStyling: Codable, Sendable {
    public let cornerRadius: String?
    public let ctaButtonBackgroundColor: String?
    public let ctaButtonTextColor: String?
    public let ctaFullWidth: Bool?
    public let ctaHeight: String?
    public let ctaWidth: String?
    public let displayDelay: String?
    public let isMovable: Bool?
    public let marginBottom: String?
    public let marginLeft: String?
    public let marginRight: String?
    public let marginTop: String?
}
