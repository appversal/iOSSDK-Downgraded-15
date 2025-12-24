//
//  File.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation

/// Manages offline event queue - stores events when network unavailable
actor PendingEventManager {
    private let userDefaults = UserDefaults.standard
    private let key = "appstorys_pending_events"
    private let csatKey = "appstorys_pending_csat_responses"
    private let userAttributesKey = "appstorys_pending_user_attributes"
    
    struct PendingEvent: Codable {
        let campaignId: String?
        let event: String
        let metadata: [String: AnyCodable]?
        let timestamp: Date
    }
    // ✅ NEW: CSAT-specific pending response
    struct PendingCsatResponse: Codable {
        let csatId: String
        let userId: String
        let rating: Int
        let feedbackOption: String?
        let additionalComments: String?
        let timestamp: Date
    }
    
    struct PendingUserAttributes: Codable {
        let userId: String
        let attributes: [String: AnyCodable]
        let timestamp: Date
    }
    
    func save(campaignId: String?, event: String, metadata: [String: AnyCodable]?) {
        var events = getAll()
        events.append(PendingEvent(
            campaignId: campaignId,
            event: event,
            metadata: metadata,
            timestamp: Date()
        ))
        
        if let data = try? JSONEncoder().encode(events) {
            userDefaults.set(data, forKey: key)
            Logger.info("💾 Event saved for retry: \(event)")
        }
    }
    
    func getAll() -> [PendingEvent] {
        guard let data = userDefaults.data(forKey: key),
              let events = try? JSONDecoder().decode([PendingEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    func clear() {
        userDefaults.removeObject(forKey: key)
        Logger.info("🗑️ Pending events cleared")
    }
    
    func saveCsatResponse(
        csatId: String,
        userId: String,
        rating: Int,
        feedbackOption: String?,
        additionalComments: String?
    ) {
        var responses = getAllCsatResponses()
        responses.append(PendingCsatResponse(
            csatId: csatId,
            userId: userId,
            rating: rating,
            feedbackOption: feedbackOption,
            additionalComments: additionalComments,
            timestamp: Date()
        ))
        
        if let data = try? JSONEncoder().encode(responses) {
            userDefaults.set(data, forKey: csatKey)
            Logger.info("💾 CSAT response queued for retry")
        }
    }
    
    func getAllCsatResponses() -> [PendingCsatResponse] {
        guard let data = userDefaults.data(forKey: csatKey),
              let responses = try? JSONDecoder().decode([PendingCsatResponse].self, from: data) else {
            return []
        }
        return responses
    }
    
    func clearCsatResponses() {
        userDefaults.removeObject(forKey: csatKey)
        Logger.info("🗑️ Pending CSAT responses cleared")
    }
    
    func savePendingUserAttributes(_ attributes: [String: AnyCodable], userId: String) {
        let pending = PendingUserAttributes(
            userId: userId,
            attributes: attributes,
            timestamp: Date()
        )
        
        if let data = try? JSONEncoder().encode(pending) {
            userDefaults.set(data, forKey: userAttributesKey)
            Logger.info("💾 User attributes queued for sync")
        }
    }
    
    /// Get pending user attributes
    func getPendingUserAttributes() -> PendingUserAttributes? {
        guard let data = userDefaults.data(forKey: userAttributesKey),
              let pending = try? JSONDecoder().decode(PendingUserAttributes.self, from: data) else {
            return nil
        }
        return pending
    }
    
    /// Clear pending user attributes
    func clearPendingUserAttributes() {
        userDefaults.removeObject(forKey: userAttributesKey)
        Logger.info("🗑️ Pending user attributes cleared")
    }
    
    
}
