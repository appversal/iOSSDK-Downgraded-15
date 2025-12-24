//
//  CsatResponseRequest.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 14/11/25.
//

import Foundation

// MARK: - Request Model
struct CsatResponseRequest: Codable {
    let csat: String
    let userId: String
    let rating: Int
    let feedbackOption: String?
    let additionalComments: String?
    
    enum CodingKeys: String, CodingKey {
        case csat
        case userId = "user_id"
        case rating
        case feedbackOption = "feedback_option"
        case additionalComments = "additional_comments"
    }
}

// MARK: - Response Model
struct CsatResponseResult: Codable {
    let success: Bool
    let message: String?
    let responseId: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case responseId = "response_id"
    }
}
