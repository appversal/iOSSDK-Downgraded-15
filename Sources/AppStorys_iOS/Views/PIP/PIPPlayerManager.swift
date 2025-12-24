//
//  PIPPlayerManager.swift
//  AppStorys_iOS
//
//  âœ… UPDATED: Added video caching support via StoryCacheManager
//

import AVKit
import Combine

@MainActor
public class PIPPlayerManager: ObservableObject {
    // MARK: - Published Properties
    @Published public var player = AVPlayer()
    @Published public var isLoading = false
    
    // MARK: - Private Properties
    private var loopObserver: NSObjectProtocol?
    private var currentVideoURL: String?
    private let cacheManager = StoryCacheManager.shared
    
    // MARK: - Initialization
    public init() {
        setupAudioSession()
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.error("Failed to setup audio session", error: error)
        }
    }
    
    // MARK: - Video Control
    
    /// âœ… NEW: Update video with cache support
    public func updateVideoURL(_ urlString: String) {
        guard urlString != currentVideoURL else {
            Logger.debug("Same video URL, skipping reload")
            return
        }
        
        guard let url = URL(string: urlString) else {
            Logger.error("Invalid video URL: \(urlString)")
            return
        }
        
        currentVideoURL = urlString
        
        Task {
            await loadVideoWithCache(url: url)
        }
    }
    
    /// âœ… NEW: Load video with cache check
    private func loadVideoWithCache(url: URL) async {
        isLoading = true
        
        // Check if video is cached
        if let cachedURL = cacheManager.getCachedVideoURLSync(for: url) {
            Logger.info("Loading PIP video from cache: \(url.lastPathComponent)")
            loadPlayer(with: cachedURL)
            isLoading = false
            return
        }
        
        // Not cached - load from network and cache in background
        Logger.info("Loading PIP video from network: \(url.lastPathComponent)")
        
        // Play from network immediately for UX
        loadPlayer(with: url)
        isLoading = false
        
        // Cache in background for next time
        Task.detached(priority: .utility) {
            do {
                let cachedURL = try await self.cacheManager.cacheVideo(url: url)
                Logger.info("PIP video cached: \(url.lastPathComponent)")
                
                // âœ… Switch to cached version if same video is still playing
                await MainActor.run {
                    if self.currentVideoURL == url.absoluteString {
                        Logger.debug("Switching PIP to cached version")
                        self.loadPlayer(with: cachedURL)
                    }
                }
            } catch {
                Logger.warning("Failed to cache PIP video: \(error.localizedDescription)")
            }
        }
    }
    
    /// âœ… NEW: Prefetch video for instant playback
    public func prefetchVideo(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // Skip if already cached
        guard !cacheManager.isVideoCached(url: url) else {
            Logger.debug("PIP video already cached, skipping prefetch")
            return
        }
        
        Logger.info("Prefetching PIP video: \(url.lastPathComponent)")
        cacheManager.prefetchVideo(url: url)
    }
    
    /// Load player with URL
    private func loadPlayer(with url: URL) {
        Logger.debug("Loading player with: \(url.lastPathComponent)")
        
        // Clean up old observer
        removeLoopObserver()
        
        // Load new video
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        // Setup looping
        setupLooping(for: playerItem)
    }
    
    private func setupLooping(for playerItem: AVPlayerItem) {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.player.seek(to: .zero)
                self?.player.play()
            }
        }
    }
    
    public func play() {
        player.play()
        Logger.debug("Video playing")
    }
    
    public func pause() {
        player.pause()
        Logger.debug("Video paused")
    }
    
    // MARK: - Cleanup
    
    /// Public cleanup method - call this explicitly when done with the player
    public func cleanup() {
        Logger.debug("Cleaning up player")
        removeLoopObserver()
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentVideoURL = nil
        isLoading = false
    }
    
    private func removeLoopObserver() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
    }
}
