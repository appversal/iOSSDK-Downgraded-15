//
//  ModalDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//

import Foundation

// MARK: - Modal Details

public struct ModalDetails: Codable, Sendable {
    let id: String?
    let modals: [ModalItem]
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id, modals, name
    }
}

// MARK: - Modal Item

public struct ModalItem: Codable, Sendable, Identifiable {
    // ✅ Generate stable ID from URL or lottieData
    public var id: String {
        url ?? lottieData ?? UUID().uuidString
    }
    
    let backgroundOpacity: StringOrInt?
    let borderRadius: StringOrInt?
    let link: String?
    let redirection: RedirectionConfig?
    let size: StringOrInt?
    let url: String?
    let lottieData: String?
    
    enum CodingKeys: String, CodingKey {
        case backgroundOpacity, borderRadius, link
        case redirection, size, url
        case lottieData = "lottie_data"
    }
    
    // MARK: - Computed Properties
    
    var backdropOpacity: Double {
        Double(backgroundOpacity?.stringValue ?? "0.5") ?? 0.5
    }

    var cornerRadius: CGFloat {
        CGFloat(Double(borderRadius?.stringValue ?? "24") ?? 24)
    }

    var modalSize: CGFloat {
        CGFloat(Double(size?.stringValue ?? "300") ?? 300)
    }

    var imageURL: URL? {
        guard let urlString = url else { return nil }
        return URL(string: URLHelper.sanitizeURL(urlString) ?? urlString)
    }
    
    var lottieURL: URL? {
        guard let urlString = lottieData else { return nil }
        return URL(string: urlString)
    }
    
    var destinationURL: URL? {
        // Priority: redirection.url > link
        if let redirectionURL = redirection?.url, !redirectionURL.isEmpty {
            return URL(string: redirectionURL)
        }
        
        if let linkURL = link, !linkURL.isEmpty {
            return URL(string: linkURL)
        }
        
        return nil
    }
}

// MARK: - Redirection Config

public struct RedirectionConfig: Codable, Sendable {
    let key: String?
    let pageName: String?
    let type: String?
    let url: String?
    let value: String?
    
    enum CodingKeys: String, CodingKey {
        case key, pageName, type, url, value
    }
}
