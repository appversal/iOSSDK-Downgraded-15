//
//  File.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation
import UIKit

@MainActor
struct DeviceInfoProvider {
    static func buildAttributes() -> [String: AnyCodable] {
        let screen = UIScreen.main
        let locale = Locale.current
        let timeZone = TimeZone.current
        
        var attributes: [String: AnyCodable] = [
            "platform": AnyCodable("ios"),
            "device_type": AnyCodable("mobile"),
            "manufacturer": AnyCodable("Apple"),
            "model": AnyCodable(deviceModel()),
            "os_version": AnyCodable(UIDevice.current.systemVersion),
            "language": AnyCodable(locale.languageCode ?? "en"),
            "locale": AnyCodable(locale.identifier),
            "timezone": AnyCodable(timeZone.identifier),
            "screen_width_px": AnyCodable(Int(screen.bounds.width * screen.scale)),
            "screen_height_px": AnyCodable(Int(screen.bounds.height * screen.scale)),
            "screen_density": AnyCodable(Double(screen.scale)),  // ← Convert CGFloat to Double
            "orientation": AnyCodable(orientation()),
            "app_version": AnyCodable(appVersion()),
            "package_name": AnyCodable(bundleIdentifier()),
        ]
        
        return attributes
    }
    
    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private static func orientation() -> String {
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape ? "landscape" : "portrait"
    }
    
    private static func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private static func bundleIdentifier() -> String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }
}
