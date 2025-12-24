//
//  TrackUserRequest.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//


import Foundation

// MARK: - Track User Request
struct TrackUserRequest: Codable {
    let userId: String
    let attributes: [String: AnyCodable]
    let screenName: String?
    let silentUpdate: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case attributes
        case screenName
        case silentUpdate
    }
}

// MARK: - Track Event Request
struct TrackEventRequest: Codable {
    let userId: String
    let event: String
    let campaignId: String
    let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case event
        case campaignId = "campaign_id"
        case metadata
    }
}