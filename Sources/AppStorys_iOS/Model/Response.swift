//
//  AccessTokenResponse.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation

// MARK: - Access Token Response
public struct AccessTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

// MARK: - WebSocket Connection Response
public struct WebSocketConnectionResponse: Codable, Sendable {
    let userID: String
    let ws: WebSocketConfig
    let screenCaptureEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case userID = "userID"
        case ws
        case screenCaptureEnabled = "screen_capture_enabled"
    }
}

public struct WebSocketConfig: Codable, Sendable {
    let expires: Int
    let sessionID: String
    let token: String
    let url: String
}

// MARK: - Campaign Response
public struct CampaignResponse: Codable, Sendable {
    let userId: String?
    let messageId: String?
    let campaigns: [CampaignModel]?
    let metadata: Metadata?
    let sentAt: Int?
    let testUser: Bool?

    enum CodingKeys: String, CodingKey {
        case userId
        case messageId = "message_id"
        case campaigns, metadata
        case sentAt = "sent_at"
        case testUser = "test_user"
    }
}

public struct Metadata: Codable, Sendable {
    let screenCaptureEnabled: Bool?
    let testUser: Bool?

    enum CodingKeys: String, CodingKey {
        case screenCaptureEnabled = "screen_capture_enabled"
        case testUser = "test_user"
    }
}
