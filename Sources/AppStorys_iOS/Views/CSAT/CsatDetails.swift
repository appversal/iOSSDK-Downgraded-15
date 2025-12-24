//
//  CsatDetails.swift
//  AppStorys_iOS
//
//
//

import Foundation

public struct CsatDetails: Codable, Sendable {
    public let id: String
    public let title: String?
    public let height: Int?
    public let width: Int?
    public let styling: CsatStyling?
    public let thankyouImage: String?
    public let thankyouText: String?
    public let thankyouDescription: String?
    public let descriptionText: String?
    public let feedbackOption: FeedbackOptions?
    public let link: String?
    public let highStarText: String?
    public let lowStarText: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, height, width, styling, link
        case thankyouImage
        case thankyouText
        case thankyouDescription
        case descriptionText = "description_text"
        case feedbackOption = "feedback_option"
        case highStarText
        case lowStarText
    }
}

public struct CsatStyling: Codable, Sendable {
    // ✅ FIXED: Handle string-to-int conversion
    public let displayDelay: Int?
    public let fontSize: Int?
    
    // Color fields
    public let csatTitleColor: String?
    public let csatCtaTextColor: String?
    public let csatBackgroundColor: String?
    public let csatOptionTextColour: String?
    public let csatOptionStrokeColor: String?
    public let csatCtaBackgroundColor: String?
    public let csatDescriptionTextColor: String?
    public let csatSelectedOptionTextColor: String?
    public let csatSelectedOptionBackgroundColor: String?
    public let csatLowStarColor: String?
    public let csatHighStarColor: String?
    public let csatAdditionalTextColor: String?
    public let csatUnselectedStarColor: String?
    
    // ✅ NEW: Missing fields from backend
    public let csatOptionBoxColour: String?
    public let csatSelectedOptionStrokeColor: String?
    public let csatFontFamily: String?
    public let csatBottomPadding: String?
    
    // ✅ CRITICAL: Custom decoder to handle type mismatches
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ✅ Handle displayDelay as String OR Int
        if let delayString = try? container.decode(String.self, forKey: .displayDelay) {
            displayDelay = Int(delayString)
        } else {
            displayDelay = try? container.decodeIfPresent(Int.self, forKey: .displayDelay)
        }
        
        // ✅ Handle fontSize as String OR Int
        if let sizeString = try? container.decode(String.self, forKey: .fontSize) {
            fontSize = Int(sizeString)
        } else {
            fontSize = try? container.decodeIfPresent(Int.self, forKey: .fontSize)
        }
        
        // Standard string fields
        csatTitleColor = try? container.decodeIfPresent(String.self, forKey: .csatTitleColor)
        csatCtaTextColor = try? container.decodeIfPresent(String.self, forKey: .csatCtaTextColor)
        csatBackgroundColor = try? container.decodeIfPresent(String.self, forKey: .csatBackgroundColor)
        csatOptionTextColour = try? container.decodeIfPresent(String.self, forKey: .csatOptionTextColour)
        csatOptionStrokeColor = try? container.decodeIfPresent(String.self, forKey: .csatOptionStrokeColor)
        csatCtaBackgroundColor = try? container.decodeIfPresent(String.self, forKey: .csatCtaBackgroundColor)
        csatDescriptionTextColor = try? container.decodeIfPresent(String.self, forKey: .csatDescriptionTextColor)
        csatSelectedOptionTextColor = try? container.decodeIfPresent(String.self, forKey: .csatSelectedOptionTextColor)
        csatSelectedOptionBackgroundColor = try? container.decodeIfPresent(String.self, forKey: .csatSelectedOptionBackgroundColor)
        csatLowStarColor = try? container.decodeIfPresent(String.self, forKey: .csatLowStarColor)
        csatHighStarColor = try? container.decodeIfPresent(String.self, forKey: .csatHighStarColor)
        csatAdditionalTextColor = try? container.decodeIfPresent(String.self, forKey: .csatAdditionalTextColor)
        csatUnselectedStarColor = try? container.decodeIfPresent(String.self, forKey: .csatUnselectedStarColor)
        
        // ✅ NEW: Previously missing fields
        csatOptionBoxColour = try? container.decodeIfPresent(String.self, forKey: .csatOptionBoxColour)
        csatSelectedOptionStrokeColor = try? container.decodeIfPresent(String.self, forKey: .csatSelectedOptionStrokeColor)
        csatFontFamily = try? container.decodeIfPresent(String.self, forKey: .csatFontFamily)
        csatBottomPadding = try? container.decodeIfPresent(String.self, forKey: .csatBottomPadding)
    }
    
    enum CodingKeys: String, CodingKey {
        case displayDelay, fontSize
        case csatTitleColor, csatCtaTextColor, csatBackgroundColor
        case csatOptionTextColour, csatOptionStrokeColor, csatCtaBackgroundColor
        case csatDescriptionTextColor, csatSelectedOptionTextColor
        case csatSelectedOptionBackgroundColor, csatLowStarColor
        case csatHighStarColor, csatAdditionalTextColor
        case csatUnselectedStarColor
        
        // ✅ NEW: Missing fields
        case csatOptionBoxColour
        case csatSelectedOptionStrokeColor
        case csatFontFamily
        case csatBottomPadding
    }
}

public struct FeedbackOptions: Codable, Sendable {
    public let options: [String]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // Decode ALL optionX values regardless of count
        var temp: [(key: String, value: String)] = []

        for key in container.allKeys {
            let value = try container.decode(String.self, forKey: key)
            temp.append((key: key.stringValue, value: value))
        }

        // Sort by option1, option2, option3… for stable order
        self.options = temp
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { $0.value }
    }

    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

