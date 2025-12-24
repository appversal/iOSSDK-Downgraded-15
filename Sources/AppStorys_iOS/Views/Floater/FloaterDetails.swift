//
//  FloaterDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//

import Foundation

public struct FloaterDetails: Codable, Sendable {
    public let id: String?
    public let image: String?
    public let lottieData: String?  // ✅ NEW: Lottie animation URL
    public let link: String?
    public let height: Double?
    public let width: Double?
    public let position: String?
    public let styling: FloaterStyling?
    
    enum CodingKeys: String, CodingKey {
        case id, image, link, height, width, position, styling
        case lottieData = "lottie_data"  // ✅ Maps to snake_case from backend
    }
}

public struct FloaterStyling: Codable, Sendable {
    public let topLeftRadius: String?
    public let topRightRadius: String?
    public let bottomLeftRadius: String?
    public let bottomRightRadius: String?
}
