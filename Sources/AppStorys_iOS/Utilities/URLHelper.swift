//
//  URLHelper.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/10/25.
//

import Foundation
import UIKit

enum URLHelper {
    /// Fix malformed URLs from backend
    static func sanitizeURL(_ urlString: String?) -> String? {
        guard let urlString = urlString, !urlString.isEmpty else {
            return nil
        }
        
        // Already has protocol
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // Fix missing protocol and slash after domain
        var fixed = urlString
        
        // Fix cloudfront URLs: "d9sydtcsqik35.cloudfront.netpip/..." → "https://d9sydtcsqik35.cloudfront.net/pip/..."
        if fixed.contains("cloudfront.net") && !fixed.contains("cloudfront.net/") {
            fixed = fixed.replacingOccurrences(of: "cloudfront.net", with: "cloudfront.net/")
        }
        
        // Add https:// prefix
        if !fixed.hasPrefix("https://") {
            fixed = "https://" + fixed
        }
        
        return fixed
    }
}

extension AppStorys {
    
    @MainActor
    static func handleSmartLink(_ value: String?) {
        guard let value = value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 1️⃣ Check if it's a Web URL
        if value.lowercased().contains("http") {
            if let sanitized = URLHelper.sanitizeURL(value),
               let url = URL(string: sanitized) {
                Logger.info("🔗 Opening URL: \(url.absoluteString)")
                UIApplication.shared.open(url)
            }
            return
        }
        
        // 2️⃣ ✅ FIXED: Campaign ID Resolution (Specific Activation)
        if let targetCampaign = AppStorys.shared.campaigns.first(where: { $0.id == value }) {
            
            if let triggerName = targetCampaign.triggerEvent, !triggerName.isEmpty {
                Logger.info("⚡️ Resolved Campaign ID [\(value)] -> Trigger Event [\(triggerName)]")
                
                // ✅ NEW: Activate ONLY this campaign (not global event)
                AppStorys.shared.activateCampaign(value)
                return
                
            } else {
                Logger.warning("⚠️ Target campaign [\(value)] has no trigger event configured.")
            }
        }
        
        // 3️⃣ Fallback: Treat as global event name
        Logger.info("⚡️ Triggering global event: \(value)")
        AppStorys.triggerEvent(value)
    }
}
