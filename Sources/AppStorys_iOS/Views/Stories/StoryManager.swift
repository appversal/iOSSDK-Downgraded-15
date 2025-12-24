//
//  StoryManager.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Added isDismissing as @Published property
//  Updated: Integrated caching and prefetching
//

import Foundation
import SwiftUI
import Combine
import Kingfisher

@MainActor
public class StoryManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var viewStates: [String: StoryViewState] = [:]
    @Published var activeCampaign: StoryCampaign?
    @Published var currentGroupIndex: Int = 0
    @Published var isPaused: Bool = false
    @Published var isDismissing: Bool = false  // ✅ NEW: Track dismissal state
    
    // MARK: - Private Properties
    
    private let persistenceKey = "appstorys_story_view_states"
    private let userDefaults = UserDefaults.standard
    private let eventTracker: (String, String, [String: Any]?) async -> Void
    private let cacheManager = StoryCacheManager.shared
    
    // MARK: - Initialization
    
    public init(eventTracker: @escaping (String, String, [String: Any]?) async -> Void) {
        self.eventTracker = eventTracker
        self.loadViewStates()
        
        // ✅ Configure Kingfisher on init
        KingfisherManager.configureForStories()
    }
    
    // MARK: - Public API
    
    public func isGroupViewed(_ storyId: String) -> Bool {
        viewStates[storyId]?.isFullyViewed ?? false
    }
    
    public func isSlideViewed(storyId: String, slideId: String) -> Bool {
        viewStates[storyId]?.viewedSlideIds.contains(slideId) ?? false
    }
    
    public func markSlideViewed(storyId: String, slideId: String, campaignId: String) {
        var state = viewStates[storyId] ?? StoryViewState(storyId: storyId)
        state.markSlideViewed(slideId)
        viewStates[storyId] = state
        
        saveViewStates()
        
        Task {
            await eventTracker("slide_viewed", campaignId, [
                "story_id": storyId,
                "slide_id": slideId
            ])
        }
    }
    
    public func markGroupFullyViewed(storyId: String, campaignId: String) {
        var state = viewStates[storyId] ?? StoryViewState(storyId: storyId)
        state.markFullyViewed()
        viewStates[storyId] = state
        
        saveViewStates()
        
        Logger.info("🏁 Story group \(storyId) marked as fully viewed")
        
        Task {
            await eventTracker("story_completed", campaignId, [
                "story_id": storyId
            ])
        }
    }
    
    /// Open a story campaign at a specific group index
    public func openStory(campaign: StoryCampaign, initialGroupIndex: Int = 0) {
        self.activeCampaign = campaign
        self.currentGroupIndex = initialGroupIndex
        self.isPaused = false
        self.isDismissing = false  // ✅ Reset dismissing state
        
        Logger.info("📖 Opening story campaign: \(campaign.id) at group \(initialGroupIndex)")
        
        // ✅ Cache campaign data
        cacheManager.cacheStoryCampaign(campaign)
        
        // ✅ Prefetch next story
        cacheManager.prefetchNextStory(campaign: campaign, currentIndex: initialGroupIndex)
        
        Task {
            let storyId = campaign.stories[safe: initialGroupIndex]?.id ?? "unknown"
            await eventTracker("story_opened", campaign.id, [
                "story_id": storyId,
                "group_index": initialGroupIndex
            ])
        }
    }
    
    public func closeStory() {
        guard !isDismissing else {
            Logger.debug("⏭️ Already dismissing, ignoring duplicate close")
            return
        }
        
        isDismissing = true  // ✅ Set dismissing flag FIRST
        
        if let campaign = activeCampaign {
            Logger.info("📕 Closing story campaign: \(campaign.id)")
            
            Task {
                await eventTracker("story_dismissed", campaign.id, nil)
            }
        }
        
        // ✅ Small delay to allow views to stop timers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            
            self.activeCampaign = nil
            self.currentGroupIndex = 0
            self.isPaused = false
            
            // Reset dismissing flag after cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isDismissing = false
            }
        }
    }
    
    // ✅ NEW: Prefetch entire campaign
    public func prefetchCampaign(_ campaign: StoryCampaign) {
        Logger.info("🔄 Prefetching campaign: \(campaign.id)")
        cacheManager.prefetchStoryCampaign(campaign)
    }
    
    public func clearAllViewStates() {
        viewStates.removeAll()
        userDefaults.removeObject(forKey: persistenceKey)
        Logger.info("🗑️ Cleared all story view states")
    }
    
    // ✅ NEW: Clear cache
    public func clearCache() {
        cacheManager.clearAllCache()
        Logger.info("🗑️ Cleared all story cache")
    }
    
    // MARK: - Persistence
    
    private func loadViewStates() {
        guard let data = userDefaults.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([String: StoryViewState].self, from: data) else {
            Logger.debug("📦 No persisted story view states found")
            return
        }
        
        self.viewStates = decoded
        Logger.info("📦 Loaded \(decoded.count) story view states from disk")
    }
    
    private func saveViewStates() {
        guard let encoded = try? JSONEncoder().encode(viewStates) else {
            Logger.error("❌ Failed to encode story view states")
            return
        }
        
        userDefaults.set(encoded, forKey: persistenceKey)
        Logger.debug("💾 Saved \(viewStates.count) story view states to disk")
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Story Index Change Observer

extension StoryManager {
    /// Call this when currentGroupIndex changes to prefetch next story
    public func onGroupIndexChanged() {
        guard let campaign = activeCampaign else { return }
        
        // ✅ Prefetch next story when user advances
        cacheManager.prefetchNextStory(campaign: campaign, currentIndex: currentGroupIndex)
    }
}
