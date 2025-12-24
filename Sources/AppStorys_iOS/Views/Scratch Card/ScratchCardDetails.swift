//
//  ScratchCardDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 17/11/25.
//

import Foundation

// MARK: - ScratchCardDetails
public struct ScratchCardDetails: Codable, Sendable, Equatable {
    public let bannerImage: String?
    public let overlayImage: String?
    public let cardSize: CardSize?
    public let rewardContent: RewardContent?
    public let coupon: Coupon?
    public let cta: CTA?
    public let termsAndConditions: String?
    public let interactions: Interactions?
    public let soundFile: String?
    
    enum CodingKeys: String, CodingKey {
        case overlayImage = "coverImage"
        case bannerImage
        case content
        case soundFile
    }
    
    enum ContentKeys: String, CodingKey {
        case cardSize = "card_size"
        case rewardContent = "reward_content"
        case coupon
        case cta
        case termsAndConditions = "terms_and_conditions"
        case interactions
    }
    
    // MARK: - Custom Decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        overlayImage = try container.decodeIfPresent(String.self, forKey: .overlayImage)
        bannerImage = try container.decodeIfPresent(String.self, forKey: .bannerImage)
        soundFile = try container.decodeIfPresent(String.self, forKey: .soundFile)
            
        if container.contains(.content) {
            let content = try container.nestedContainer(keyedBy: ContentKeys.self, forKey: .content)
            
            cardSize = try content.decodeIfPresent(CardSize.self, forKey: .cardSize)
            rewardContent = try content.decodeIfPresent(RewardContent.self, forKey: .rewardContent)
            coupon = try content.decodeIfPresent(Coupon.self, forKey: .coupon)
            cta = try content.decodeIfPresent(CTA.self, forKey: .cta)
            termsAndConditions = try content.decodeIfPresent(String.self, forKey: .termsAndConditions)
            interactions = try content.decodeIfPresent(Interactions.self, forKey: .interactions)
        } else {
            cardSize = nil
            rewardContent = nil
            coupon = nil
            cta = nil
            termsAndConditions = nil
            interactions = nil
        }
    }
    
    // MARK: - Custom Encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(overlayImage, forKey: .overlayImage)
        try container.encodeIfPresent(bannerImage, forKey: .bannerImage)
        try container.encodeIfPresent(soundFile, forKey: .soundFile)

        var content = container.nestedContainer(keyedBy: ContentKeys.self, forKey: .content)
        
        try content.encodeIfPresent(cardSize, forKey: .cardSize)
        try content.encodeIfPresent(rewardContent, forKey: .rewardContent)
        try content.encodeIfPresent(coupon, forKey: .coupon)
        try content.encodeIfPresent(cta, forKey: .cta)
        try content.encodeIfPresent(termsAndConditions, forKey: .termsAndConditions)
        try content.encodeIfPresent(interactions, forKey: .interactions)
    }
}


// MARK: - ContentWrapper (for nested decoding)
private struct ContentWrapper: Codable {
    let cardSize: CardSize?
    let rewardContent: RewardContent?
    let coupon: Coupon?
    let cta: CTA?
    let termsAndConditions: String?
    
    enum CodingKeys: String, CodingKey {
        case cardSize = "card_size"
        case rewardContent = "reward_content"
        case coupon
        case cta
        case termsAndConditions = "terms_and_conditions"
    }
}

// MARK: - CardSize
public struct CardSize: Codable, Sendable, Equatable {
    public let width: Int?
    public let height: Int?
    public let cornerRadius: Int?
    
    enum CodingKeys: String, CodingKey {
        case width, height
        case cornerRadius = "corner_radius"
    }
    
    public init(width: Int?, height: Int?, cornerRadius: Int?) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
}

// MARK: - RewardContent
public struct RewardContent: Codable, Sendable, Equatable {
    public let brandName: String?
    public let offerTitle: String?
    public let backgroundColor: String?
    public let onlyImage: Bool?
    public let offerTitleTextColor: String?
    public let offerSubtitleTextColor: String?
    public let titleFontSize: StringOrInt?
    public let subtitleFontSize: StringOrInt?
    public let imageSize: StringOrInt?
    
    enum CodingKeys: String, CodingKey {
        case brandName = "offer_title"
        case offerTitle = "offer_subtitle"
        case backgroundColor = "background_color"
        case onlyImage = "onlyImage"
        case offerTitleTextColor = "offerTitleTextColor"
        case offerSubtitleTextColor = "offerSubtitleTextColor"
        case titleFontSize
        case subtitleFontSize
        case imageSize
    }
    
    public init(
        brandName: String?,
        offerTitle: String?,
        backgroundColor: String?,
        onlyImage: Bool?,
        offerTitleTextColor: String?,
        offerSubtitleTextColor: String?,
        titleFontSize: StringOrInt?,
        subtitleFontSize: StringOrInt?,
        imageSize: StringOrInt?
        
    ) {
        self.brandName = brandName
        self.offerTitle = offerTitle
        self.backgroundColor = backgroundColor
        self.onlyImage = onlyImage
        self.offerTitleTextColor = offerTitleTextColor
        self.offerSubtitleTextColor = offerSubtitleTextColor
        self.titleFontSize = titleFontSize
        self.subtitleFontSize = subtitleFontSize
        self.imageSize = imageSize
    }
}

// MARK: - Coupon
public struct Coupon: Codable, Sendable, Equatable {
    public let code: String?
    public let borderColor: String?
    public let backgroundColor: String?
    public let codeTextColor: String?
    
    enum CodingKeys: String, CodingKey {
        case code
        case borderColor = "border_color"
        case backgroundColor = "background_color"
        case codeTextColor = "codeTextColor"
    }
    
    public init(
        code: String?,
        borderColor: String?,
        backgroundColor: String?,
        codeTextColor: String?
    ) {
        self.code = code
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.codeTextColor = codeTextColor
    }
}

// MARK: - CTA
public struct CTA: Codable, Sendable, Equatable {
    public let buttonText: String?
    public let buttonColor: String?
    public let url: String?
    public let height: Int?
    public let width: Int?
    public let ctaTextColor: String?
    public let borderRadius: Int?
    public let enableFullWidth: Bool?
    public let padding: Padding?
    public let ctaFontSize: StringOrInt?
    
    enum CodingKeys: String, CodingKey {
        case buttonText = "button_text"
        case buttonColor = "button_color"
        case url, height, width
        case ctaTextColor = "cta_text_color"
        case borderRadius = "border_radius"
        case enableFullWidth = "enable_full_width"
        case padding
        case ctaFontSize
    }
    
    public init(
        buttonText: String?,
        buttonColor: String?,
        url: String?,
        height: Int?,
        width: Int?,
        ctaTextColor: String?,
        borderRadius: Int?,
        enableFullWidth: Bool?,
        padding: Padding?,
        ctaFontSize: StringOrInt?
    ) {
        self.buttonText = buttonText
        self.buttonColor = buttonColor
        self.url = url
        self.height = height
        self.width = width
        self.ctaTextColor = ctaTextColor
        self.borderRadius = borderRadius
        self.enableFullWidth = enableFullWidth
        self.padding = padding
        self.ctaFontSize = ctaFontSize
    }
}

// MARK: - Padding
public struct Padding: Codable, Sendable, Equatable {
    public let top: Int?
    public let bottom: Int?
    public let left: Int?
    public let right: Int?
    
    public init(top: Int?, bottom: Int?, left: Int?, right: Int?) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
}

// MARK: - Interactions
public struct Interactions: Codable, Sendable, Equatable {
    public let haptics: Bool?

    enum CodingKeys: String, CodingKey {
        case haptics
    }
}
