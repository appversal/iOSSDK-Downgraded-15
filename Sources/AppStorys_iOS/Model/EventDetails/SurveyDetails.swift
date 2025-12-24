//
//  SurveyDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//


import Foundation

public struct SurveyDetails: Codable, Sendable {
    public let id: String
    public let name: String?
    public let styling: [String: String]?
    public let surveyQuestion: String?
    public let surveyOptions: [String: String]?
    public let hasOthers: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, styling
        case surveyQuestion = "surveyQuestion"
        case surveyOptions = "surveyOptions"
        case hasOthers
    }
}