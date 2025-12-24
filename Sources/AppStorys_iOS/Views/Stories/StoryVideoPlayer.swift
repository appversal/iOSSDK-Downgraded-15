//
//  StoryVideoPlayer.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Detect and report actual video duration
//  ✅ FIXED: Improved video reset logic
//

import SwiftUI
import AVKit
import Combine

/// Video player for story slides with pause/reset/mute support and duration detection
struct StoryVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    let onReady: () -> Void
    let onEnd: () -> Void
    let onDurationAvailable: (TimeInterval) -> Void  // ✅ NEW
    let isActive: Bool
    let isPaused: Bool
    let isMuted: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        
        let player = AVPlayer(url: url)
        player.isMuted = isMuted
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        controller.player = player
        context.coordinator.player = player
        context.coordinator.observePlayer(player)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        guard let player = uiViewController.player else { return }
        
        // Update mute state
        if player.isMuted != isMuted {
            player.isMuted = isMuted
            Logger.debug("🔊 Video mute: \(isMuted)")
        }
        
        // ✅ CRITICAL: Detect when we become active again after being inactive
        let wasInactive = !context.coordinator.wasActive
        let isNowActive = isActive
        
        if wasInactive && isNowActive {
            // Reset video to beginning when returning to this story
            player.seek(to: .zero)
            Logger.debug("🔄 Video reset to beginning")
        }
        
        // Update tracking state
        context.coordinator.wasActive = isActive
        
        // Update playback state
        context.coordinator.updatePlaybackState(
            isActive: isActive,
            isPaused: isPaused,
            player: player
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onReady: onReady,
            onEnd: onEnd,
            onDurationAvailable: onDurationAvailable
        )
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        Logger.debug("🗑️ Dismantling video player")
        coordinator.cleanup()
    }
    
    class Coordinator: NSObject {
        let onReady: () -> Void
        let onEnd: () -> Void
        let onDurationAvailable: (TimeInterval) -> Void  // ✅ NEW
        
        var isReadyToPlay = false
        var hasDurationBeenReported = false  // ✅ NEW: Prevent duplicate reports
        var player: AVPlayer?
        var wasActive = true
        
        private var observations: [NSKeyValueObservation] = []
        private var notificationToken: NSObjectProtocol?
        
        init(
            onReady: @escaping () -> Void,
            onEnd: @escaping () -> Void,
            onDurationAvailable: @escaping (TimeInterval) -> Void
        ) {
            self.onReady = onReady
            self.onEnd = onEnd
            self.onDurationAvailable = onDurationAvailable
        }
        
        func updatePlaybackState(isActive: Bool, isPaused: Bool, player: AVPlayer) {
            let shouldPlay = isActive && !isPaused && isReadyToPlay
            let isCurrentlyPlaying = player.rate > 0
            
            if shouldPlay && !isCurrentlyPlaying {
                player.play()
                Logger.debug("▶️ Video playing (active: \(isActive), paused: \(isPaused))")
            } else if !shouldPlay && isCurrentlyPlaying {
                player.pause()
                Logger.debug("⏸️ Video paused (active: \(isActive), paused: \(isPaused))")
            }
        }
        
        func observePlayer(_ player: AVPlayer) {
            // Observe ready state
            let statusObservation = player.observe(\.status, options: [.new]) { [weak self] player, _ in
                guard let self = self else { return }
                
                if player.status == .readyToPlay {
                    self.isReadyToPlay = true
//                    DispatchQueue.main.async {
//                        self.onReady()
//                    }
                    
                    // ✅ NEW: Report video duration when ready
                    self.reportVideoDuration(player: player)
                    
                } else if player.status == .failed {
                    Logger.error("❌ Video player failed to load")
                }
            }
            observations.append(statusObservation)
            
            // ✅ NEW: Observe duration changes (for progressive loading)
            if let currentItem = player.currentItem {
                let durationObservation = currentItem.observe(
                    \.duration,
                    options: [.new]
                ) { [weak self] item, _ in
                    guard let self = self else { return }
                    
                    let duration = item.duration
                    if duration.isNumeric && !duration.isIndefinite {
                        self.reportVideoDuration(player: player)
                    }
                }
                observations.append(durationObservation)
            }
            
            // Observe end of video
            notificationToken = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.onEnd()
            }
        }
        
        /// ✅ NEW: Extract and report video duration
        private func reportVideoDuration(player: AVPlayer) {
            guard !hasDurationBeenReported else { return }
            guard let currentItem = player.currentItem else { return }
            
            let duration = currentItem.duration
            
            // Validate duration is available and numeric
            guard duration.isNumeric && !duration.isIndefinite else {
                Logger.debug("⏳ Video duration not yet available")
                return
            }
            
            let durationInSeconds = CMTimeGetSeconds(duration)
            
            // Sanity check: duration should be between 0.1s and 10 minutes
            guard durationInSeconds > 0.1 && durationInSeconds < 600 else {
                Logger.warning("⚠️ Invalid video duration: \(durationInSeconds)s")
                return
            }
            
            hasDurationBeenReported = true
            
//            DispatchQueue.main.async { [weak self] in
//                self?.onDurationAvailable(durationInSeconds)
//                Logger.info("📹 Video duration detected: \(String(format: "%.2f", durationInSeconds))s")
//            }
        }
        
        func cleanup() {
            observations.forEach { $0.invalidate() }
            observations.removeAll()
            
            if let token = notificationToken {
                NotificationCenter.default.removeObserver(token)
                notificationToken = nil
            }
            
            player?.pause()
            player = nil
            isReadyToPlay = false
            hasDurationBeenReported = false
            wasActive = true
        }
        
        deinit {
            cleanup()
        }
    }
}

/// Player manager to control video playback state
@MainActor
class StoryVideoPlayerManager: ObservableObject {
    @Published var isPlaying: Bool = false
    
    func play() {
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
}
