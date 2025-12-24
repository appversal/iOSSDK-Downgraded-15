//
//  BottomSheetDetails.swift
//  AppStorys_iOS
//
//  Complete model with all JSON properties
//

import Foundation

public struct BottomSheetDetails: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let cornerRadius: String?
    public let elements: [BottomSheetElement]?
    public let enableCrossButton: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, cornerRadius, elements, enableCrossButton
    }
}

public struct FontStyle: Codable, Sendable {
    public let colour: String?
    public let decoration: [String]?
    public let fontFamily: String?
}

public struct BottomSheetElement: Codable, Sendable {
    public let id: String
    public let type: String
    public let order: Int
    public let alignment: String?
    
    // Padding - using PaddingValue to handle both "20" and 0
    public let paddingTop: PaddingValue?
    public let paddingBottom: PaddingValue?
    public let paddingLeft: PaddingValue?
    public let paddingRight: PaddingValue?
    
    // Image properties
    public let url: String?
    public let imageLink: String?
    public let overlayButton: Bool?
    
    // Body properties
    public let bodyBackgroundColor: String?
    public let titleText: String?
    public let titleFontSize: Int?
    public let titleLineHeight: Double?
    public let titleFontStyle: FontStyle?
    public let descriptionText: String?
    public let descriptionFontSize: Int?
    public let descriptionLineHeight: Double?
    public let descriptionFontStyle: FontStyle?
    public let spacingBetweenTitleDesc: String?
    
    // CTA properties
    public let ctaText: String?
    public let ctaLink: String?
    public let ctaBorderRadius: Int?
    public let ctaBoxColor: String?
    public let ctaFontDecoration: [String]?
    public let ctaFontFamily: String?
    public let ctaFontSize: Int?
    public let ctaTextColour: String?
    public let ctaFullWidth: Bool?
    public let ctaHeight: Int?
    public let ctaWidth: Int?
    public let position: String?
}

// Helper to handle mixed Int/String padding values
public enum PaddingValue: Codable, Sendable {
    case int(Int)
    case string(String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(PaddingValue.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                debugDescription: "Expected Int or String"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
    
    public var intValue: Int {
        switch self {
        case .int(let value): return value
        case .string(let value): return Int(value) ?? 0
        }
    }
}
