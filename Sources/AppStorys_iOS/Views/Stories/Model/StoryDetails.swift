//
//  StoryDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 14/10/25.
//

import Foundation

// MARK: - Story Details (from API)

public struct StoryDetails: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let thumbnail: String
    public let ringColor: String
    public let nameColor: String
    public let order: Int
    public let slides: [StorySlide]
    public let styling: StoryStyling?
    
    enum CodingKeys: String, CodingKey {
        case id, name, thumbnail, order, slides, styling, ringColor, nameColor
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        thumbnail = try container.decode(String.self, forKey: .thumbnail)
        ringColor = try container.decodeIfPresent(String.self, forKey: .ringColor) ?? "#FFFFFF"
        nameColor = try container.decodeIfPresent(String.self, forKey: .nameColor) ?? "#FFFFFF"
        order = try container.decode(Int.self, forKey: .order)
        styling = try container.decodeIfPresent(StoryStyling.self, forKey: .styling)
        
        // Decode and sort slides
        var slidesArray = try container.decode([StorySlide].self, forKey: .slides)
        slidesArray.sort { $0.order < $1.order }
        slides = slidesArray
        
        Logger.debug("🎨 Story colors: ring=\(ringColor), name=\(nameColor)")
    }
}

public struct StorySlide: Codable, Sendable, Identifiable {
    public let id: String
    public let parent: String
    public let order: Int
    public let image: String?
    public let video: String?
    public let link: String?
    public let buttonText: String?
    public let content: String?
    
    enum CodingKeys: String, CodingKey {
        case id, parent, order, image, video, link, content
        case buttonText = "button_text"
    }
    
    public var mediaType: MediaType {
        if video != nil { return .video }
        if image != nil { return .image }
        return .none
    }
    
    public var mediaURL: URL? {
        if let videoURL = video, let url = URL(string: videoURL) {
            return url
        }
        if let imageURL = image, let url = URL(string: imageURL) {
            return url
        }
        return nil
    }
    
    public enum MediaType {
        case image
        case video
        case none
    }
}

public struct StoryStyling: Codable, Sendable {
    public let size: Double?
    public let ringWidth: Double?
    public let spacing: Double?
    
    enum CodingKeys: String, CodingKey {
        case size
        case ringWidth = "ring_width"
        case spacing
    }
    
    // ✅ Custom decoder to handle string/number/empty/nil
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle size - can be empty string, number string, number, or nil
        if let sizeString = try? container.decode(String.self, forKey: .size) {
            if sizeString.isEmpty {
                size = nil // Empty string → nil
            } else if let sizeValue = Double(sizeString) {
                size = sizeValue // Valid number string → number
            } else {
                size = nil // Invalid string → nil
            }
        } else if let sizeDouble = try? container.decode(Double.self, forKey: .size) {
            size = sizeDouble // Direct number
        } else {
            size = nil // Missing or null
        }
        
        // Handle ring width (same logic)
        if let widthString = try? container.decode(String.self, forKey: .ringWidth) {
            if widthString.isEmpty {
                ringWidth = nil
            } else if let widthValue = Double(widthString) {
                ringWidth = widthValue
            } else {
                ringWidth = nil
            }
        } else if let widthDouble = try? container.decode(Double.self, forKey: .ringWidth) {
            ringWidth = widthDouble
        } else {
            ringWidth = nil
        }
        
        // Handle spacing (same logic)
        if let spacingString = try? container.decode(String.self, forKey: .spacing) {
            if spacingString.isEmpty {
                spacing = nil
            } else if let spacingValue = Double(spacingString) {
                spacing = spacingValue
            } else {
                spacing = nil
            }
        } else if let spacingDouble = try? container.decode(Double.self, forKey: .spacing) {
            spacing = spacingDouble
        } else {
            spacing = nil
        }
    }
}

// MARK: - Story State (Runtime)

/// Tracks viewing state for a story group
public struct StoryViewState: Codable, Sendable, Equatable {
    public let storyId: String
    public var viewedSlideIds: Set<String>
    public var lastViewedAt: Date
    public var isFullyViewed: Bool
    
    public init(storyId: String) {
        self.storyId = storyId
        self.viewedSlideIds = []
        self.lastViewedAt = Date()
        self.isFullyViewed = false
    }
    
    public mutating func markSlideViewed(_ slideId: String) {
        viewedSlideIds.insert(slideId)
        lastViewedAt = Date()
    }
    
    public mutating func markFullyViewed() {
        isFullyViewed = true
        lastViewedAt = Date()
    }
}

// MARK: - Story Progress (UI State)

/// Represents real-time progress through a story
public struct StoryProgress: Equatable {
    public let currentGroupIndex: Int
    public let currentSlideIndex: Int
    public let progress: Double // 0.0 to 1.0
    
    public init(groupIndex: Int, slideIndex: Int, progress: Double) {
        self.currentGroupIndex = groupIndex
        self.currentSlideIndex = slideIndex
        self.progress = min(max(progress, 0.0), 1.0)
    }
}

// MARK: - Story Campaign (Complete Campaign Data)

/// Represents a complete story campaign with all stories
public struct StoryCampaign: Identifiable, Sendable, Equatable {
    public let id: String
    public let campaignType: String
    public let clientId: String
    public let stories: [StoryDetails]
    
    public init(id: String, campaignType: String, clientId: String, stories: [StoryDetails]) {
        self.id = id
        self.campaignType = campaignType
        self.clientId = clientId
        // Sort stories by order
        self.stories = stories.sorted { $0.order < $1.order }
    }
    
    public static func == (lhs: StoryCampaign, rhs: StoryCampaign) -> Bool {
        lhs.id == rhs.id && lhs.stories.count == rhs.stories.count
    }
    
    /// Get story at index with view state applied
    public func story(at index: Int, viewStates: [String: StoryViewState]) -> (story: StoryDetails, isViewed: Bool) {
        guard index < stories.count else {
            return (stories[0], false)
        }
        let story = stories[index]
        let isViewed = viewStates[story.id]?.isFullyViewed ?? false
        return (story, isViewed)
    }
}
