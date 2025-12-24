//
//  BannerDetails.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//

import Foundation

public struct BannerDetails: Codable, Sendable {
    public let id: String?
    public let image: String?
    public let lottieData: String?  // ✅ NEW: Lottie animation URL
    public let width: Int?
    public let height: Int?
    public let link: String?
    public let styling: BannerStyling?
    
    enum CodingKeys: String, CodingKey {
        case id, image, width, height, link, styling
        case lottieData = "lottie_data"  // ✅ Maps to snake_case from backend
    }
}

public struct BannerStyling: Codable, Sendable {
    public let marginBottom: StringOrInt?
    public let marginLeft: StringOrInt?
    public let marginRight: StringOrInt?
    public let topLeftRadius: StringOrInt?
    public let topRightRadius: StringOrInt?
    public let bottomLeftRadius: StringOrInt?
    public let bottomRightRadius: StringOrInt?
    public let enableCloseButton: Bool?
}

public enum StringOrInt: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .string(String(doubleVal))
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else {
            throw DecodingError.typeMismatch(
                StringOrInt.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or Int or Double"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }

    /// Return as string
    public var stringValue: String {
        switch self {
        case .int(let v): return "\(v)"
        case .string(let v): return v
        }
    }

    /// Return as Double (if possible)
    public var doubleValue: Double? {
        switch self {
        case .int(let v): return Double(v)
        case .string(let v): return Double(v)
        }
    }

    /// Useful for UI fallback
    public var doubleValueOrZero: Double {
        doubleValue ?? 0
    }

    public static func == (lhs: StringOrInt, rhs: StringOrInt) -> Bool {
        lhs.stringValue == rhs.stringValue
    }
}

