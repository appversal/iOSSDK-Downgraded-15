//
//  CampaignAudioManager.swift
//  AppStorys_iOS
//
//  🔊 Centralized audio playback for campaigns
//  ✅ Handles system sounds + remote URLs
//  ✅ Caching to avoid re-downloads
//  ✅ Proper audio session management
//

import AVFoundation
import AudioToolbox
import UIKit

/// Manages audio playback for campaign celebrations and effects
@MainActor
final class CampaignAudioManager {
    
    // MARK: - Singleton
    static let shared = CampaignAudioManager()
    
    // MARK: - Properties
    private var audioCache: [String: AVPlayer] = [:]
    private var currentPlayer: AVPlayer?
    private let maxCacheSize = 10
    
    // System sound IDs
    enum SystemSound: SystemSoundID {
        case confetti = 1025
        case success = 1054
        case chime = 1052
    }
    
    // MARK: - Init
    private init() {
        configureAudioSession()
        setupNotificationObservers()
    }
    
    // MARK: - Public API
    
    /// Play confetti celebration sound
    /// - Parameter soundURL: Optional remote sound URL (falls back to system sound)
    func playConfettiSound(soundURL: String? = nil) {
        if let urlString = soundURL, !urlString.isEmpty {
            playRemoteSound(urlString)
        } else {
            playSystemSound(.confetti)
        }
    }
    
    /// Play system sound effect
    /// - Parameter sound: System sound type
    func playSystemSound(_ sound: SystemSound) {
        AudioServicesPlaySystemSound(sound.rawValue)
        Logger.debug("🔊 Playing system sound: \(sound)")
    }
    
    /// Preload remote sound for instant playback
    /// - Parameter urlString: Remote audio URL
    func preloadSound(urlString: String) async {
        guard !urlString.isEmpty,
              audioCache[urlString] == nil,
              let url = URL(string: urlString) else {
            return
        }
        
        Logger.debug("⬇️ Preloading sound: \(urlString)")
        
        let player = AVPlayer(url: url)
        
        // Preload the audio buffer
        _ = try? await player.currentItem?.asset.load(.isPlayable)
        
        // Cache the player
        audioCache[urlString] = player
        
        // Trim cache if needed
        trimCacheIfNeeded()
        
        Logger.debug("✅ Sound preloaded: \(urlString)")
    }
    
    /// Stop all audio playback
    func stopAll() {
        currentPlayer?.pause()
        currentPlayer = nil
        Logger.debug("⏸️ Stopped all audio")
    }
    
    /// Clear audio cache
    func clearCache() {
        audioCache.removeAll()
        Logger.debug("🗑️ Audio cache cleared")
    }
    
    // MARK: - Private Helpers
    
    private func playRemoteSound(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            Logger.warning("⚠️ Invalid sound URL: \(urlString), falling back to system sound")
            playSystemSound(.confetti)
            return
        }
        
        Logger.debug("🔊 Playing remote sound: \(urlString)")
        
        // Use cached player if available
        let player = audioCache[urlString] ?? AVPlayer(url: url)
        
        // Store reference to prevent deallocation
        currentPlayer = player
        
        // Cache for next time
        if audioCache[urlString] == nil {
            audioCache[urlString] = player
            trimCacheIfNeeded()
        }
        
        // Reset to beginning and play
        player.seek(to: .zero)
        player.play()
        
        // Observe playback completion
        observePlaybackEnd(for: player)
    }
    
    private func observePlaybackEnd(for player: AVPlayer) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.currentPlayer = nil
            Logger.debug("✅ Sound playback completed")
        }
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Use ambient category to mix with other audio
            try session.setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            
            try session.setActive(true)
            
            Logger.debug("🎵 Audio session configured")
            
        } catch {
            Logger.error("❌ Failed to configure audio session", error: error)
        }
    }
    
    private func trimCacheIfNeeded() {
        guard audioCache.count > maxCacheSize else { return }
        
        // Remove oldest entries (simple FIFO strategy)
        let toRemove = audioCache.count - maxCacheSize
        let keysToRemove = Array(audioCache.keys.prefix(toRemove))
        
        keysToRemove.forEach { audioCache.removeValue(forKey: $0) }
        
        Logger.debug("🧹 Trimmed audio cache: removed \(toRemove) entries")
    }
    
    private func setupNotificationObservers() {
        // Pause on app backgrounding
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopAll()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
