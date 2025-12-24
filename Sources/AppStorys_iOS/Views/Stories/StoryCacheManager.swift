//
//  StoryCacheManager.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 26/10/25.
//


//
//  StoryCacheManager.swift
//  AppStorys_iOS
//
//  Story caching and prefetching manager
//

import Foundation
import UIKit
import Kingfisher

/// Manages caching and prefetching for story content
@MainActor
class StoryCacheManager: ObservableObject {
    static let shared = StoryCacheManager()
    
    // MARK: - Cache Configuration
    
    private let memoryCacheLimit = 100 * 1024 * 1024 // 100 MB
    private let diskCacheLimit = 500 * 1024 * 1024   // 500 MB
    private let cacheExpirationDays = 7
    
    // MARK: - Cache Storage
    
    private let fileManager = FileManager.default
    private let videoCacheDirectory: URL
    private var memoryCache = NSCache<NSString, NSData>()
    
    // Track ongoing downloads to prevent duplicates
    private var activeDownloads: Set<String> = []
    
    // MARK: - Initialization
    
    init() {
        // Setup video cache directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        videoCacheDirectory = cacheDir.appendingPathComponent("AppStorys/Videos", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: videoCacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.totalCostLimit = memoryCacheLimit
        memoryCache.countLimit = 50 // Max 50 videos in memory
        
        Logger.info("📦 Story cache initialized at: \(videoCacheDirectory.path)")
        
        // Clean old cache on init
        Task {
            await cleanExpiredCache()
        }
    }
    
    // MARK: - Story Data Caching
    
    /// Cache story campaign data
    func cacheStoryCampaign(_ campaign: StoryCampaign) {
        let key = "campaign_\(campaign.id)"
        
        do {
            let data = try JSONEncoder().encode(campaign)
            UserDefaults.standard.set(data, forKey: key)
            Logger.debug("💾 Cached story campaign: \(campaign.id)")
        } catch {
            Logger.error("❌ Failed to cache campaign", error: error)
        }
    }
    
    /// Retrieve cached story campaign
    func getCachedStoryCampaign(id: String) -> StoryCampaign? {
        let key = "campaign_\(id)"
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        do {
            let campaign = try JSONDecoder().decode(StoryCampaign.self, from: data)
            Logger.debug("📦 Retrieved cached campaign: \(id)")
            return campaign
        } catch {
            Logger.error("❌ Failed to decode cached campaign", error: error)
            return nil
        }
    }
    
    // MARK: - Video Caching
    
    /// Check if video is cached
    func isVideoCached(url: URL) -> Bool {
        let cacheURL = videoCacheURL(for: url)
        return fileManager.fileExists(atPath: cacheURL.path)
    }
    
    /// Get cached video URL (returns nil if not cached)
    func getCachedVideoURL(for url: URL) -> URL? {
        let cacheURL = videoCacheURL(for: url)
        
        guard fileManager.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        
        // Update access time
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: cacheURL.path)
        
        return cacheURL
    }
    func getCachedVideoURLSync(for url: URL) -> URL? {
        let cacheURL = videoCacheURL(for: url)
        
        guard fileManager.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        
        // Update access time
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: cacheURL.path)
        
        return cacheURL
    }
    /// Download and cache video
    func cacheVideo(url: URL) async throws -> URL {
        let cacheURL = videoCacheURL(for: url)
        
        // Return if already cached
        if fileManager.fileExists(atPath: cacheURL.path) {
            Logger.debug("✅ Video already cached: \(url.lastPathComponent)")
            return cacheURL
        }
        
        // Check if download is already in progress
        let urlString = url.absoluteString
        guard !activeDownloads.contains(urlString) else {
            Logger.debug("⏳ Video download already in progress: \(url.lastPathComponent)")
            // Wait for existing download
            while activeDownloads.contains(urlString) {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            return cacheURL
        }
        
        // Mark download as active
        activeDownloads.insert(urlString)
        defer { activeDownloads.remove(urlString) }
        
        Logger.info("📥 Downloading video: \(url.lastPathComponent)")
        
        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw CacheError.downloadFailed
            }
            
            // Move to cache directory
            try? fileManager.removeItem(at: cacheURL) // Remove old if exists
            try fileManager.moveItem(at: tempURL, to: cacheURL)
            
            Logger.info("✅ Video cached: \(url.lastPathComponent) (\(fileSize(at: cacheURL)))")
            
            return cacheURL
            
        } catch {
            Logger.error("❌ Failed to cache video", error: error)
            throw error
        }
    }
    
    /// Prefetch video in background (non-blocking)
    func prefetchVideo(url: URL) {
        guard !isVideoCached(url: url) else { return }
        
        Task.detached(priority: .background) {
            do {
                _ = try await self.cacheVideo(url: url)
            } catch {
                Logger.warning("⚠️ Prefetch failed for video: \(url.lastPathComponent)")
            }
        }
    }
    
    // MARK: - Prefetching Strategies
    
    /// Prefetch all content for a story campaign
    func prefetchStoryCampaign(_ campaign: StoryCampaign) {
        Logger.info("🔄 Prefetching story campaign: \(campaign.id)")
        
        for story in campaign.stories {
            // Prefetch story thumbnail
            if let thumbnailURL = URL(string: story.thumbnail) {
                KingfisherManager.shared.retrieveImage(with: thumbnailURL) { _ in }
            }
            
            // Prefetch all slides
            for slide in story.slides {
                // Prefetch images
                if let imageURL = slide.mediaURL, slide.mediaType == .image {
                    KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
                }
                
                // Prefetch videos
                if let videoURL = slide.mediaURL, slide.mediaType == .video {
                    prefetchVideo(url: videoURL)
                }
            }
        }
    }
    
    /// Prefetch next story in sequence (smart prefetching)
    func prefetchNextStory(campaign: StoryCampaign, currentIndex: Int) {
        guard currentIndex + 1 < campaign.stories.count else {
            Logger.debug("📍 Last story in campaign, no next story to prefetch")
            return
        }
        
        let nextStory = campaign.stories[currentIndex + 1]
        Logger.info("🔮 Prefetching next story: \(nextStory.id)")
        
        // Prefetch all slides of next story
        for slide in nextStory.slides {
            if let mediaURL = slide.mediaURL {
                switch slide.mediaType {
                case .image:
                    KingfisherManager.shared.retrieveImage(with: mediaURL) { _ in }
                case .video:
                    prefetchVideo(url: mediaURL)
                case .none:
                    break
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    /// Get total cache size
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: videoCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return 0
        }
        
        for fileURL in files {
            if let fileSize = try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    /// Clean expired cache (older than 7 days)
    func cleanExpiredCache() async {
        let expirationDate = Date().addingTimeInterval(-Double(cacheExpirationDays * 24 * 60 * 60))
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: videoCacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        var deletedCount = 0
        var freedSpace: Int64 = 0
        
        for fileURL in files {
            if let modificationDate = try? fileManager.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date,
               modificationDate < expirationDate {
                
                let fileSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                
                try? fileManager.removeItem(at: fileURL)
                deletedCount += 1
                freedSpace += fileSize
            }
        }
        
        if deletedCount > 0 {
            Logger.info("🧹 Cleaned \(deletedCount) expired videos, freed \(freedSpace / 1024 / 1024)MB")
        }
    }
    
    /// Clear all video cache
    func clearAllCache() {
        try? fileManager.removeItem(at: videoCacheDirectory)
        try? fileManager.createDirectory(at: videoCacheDirectory, withIntermediateDirectories: true)
        memoryCache.removeAllObjects()
        
        Logger.info("🗑️ Cleared all story cache")
    }
    
    /// Enforce cache size limit (LRU eviction)
    func enforceStorageLimit() async {
        let currentSize = getCacheSize()
        
        guard currentSize > diskCacheLimit else {
            Logger.debug("✅ Cache size within limit: \(currentSize / 1024 / 1024)MB / \(diskCacheLimit / 1024 / 1024)MB")
            return
        }
        
        Logger.warning("⚠️ Cache size exceeds limit: \(currentSize / 1024 / 1024)MB")
        
        // Get all files sorted by modification date (oldest first)
        guard let files = try? fileManager.contentsOfDirectory(
            at: videoCacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }
        
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return date1 < date2
        }
        
        var currentTotal = currentSize
        var deletedCount = 0
        
        // Delete oldest files until under limit
        for fileURL in sortedFiles {
            guard currentTotal > diskCacheLimit else { break }
            
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            
            try? fileManager.removeItem(at: fileURL)
            currentTotal -= Int64(fileSize)
            deletedCount += 1
        }
        
        Logger.info("🧹 Evicted \(deletedCount) old videos to enforce cache limit")
    }
    
    // MARK: - Helper Methods
    
    private func videoCacheURL(for url: URL) -> URL {
        let filename = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.lastPathComponent
        return videoCacheDirectory.appendingPathComponent(filename)
    }
    
    private func fileSize(at url: URL) -> String {
        guard let size = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return "unknown"
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Cache Errors

enum CacheError: Error {
    case downloadFailed
    case fileNotFound
    case invalidURL
}

// MARK: - Codable Extension for StoryCampaign

extension StoryCampaign: Codable {
    enum CodingKeys: String, CodingKey {
        case id, campaignType, clientId, stories
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        campaignType = try container.decode(String.self, forKey: .campaignType)
        clientId = try container.decode(String.self, forKey: .clientId)
        stories = try container.decode([StoryDetails].self, forKey: .stories)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(campaignType, forKey: .campaignType)
        try container.encode(clientId, forKey: .clientId)
        try container.encode(stories, forKey: .stories)
    }
}
