//
//  StoryCardView.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Dynamic duration support for videos and images
//  ✅ FIXED: Proper synchronization between timer and video playback
//

import SwiftUI
import Combine
import AVFoundation

struct StoryCardView: View {
    @ObservedObject var manager: StoryManager
    let campaign: StoryCampaign
    let story: StoryDetails
    let groupIndex: Int
    let dragOffsetOpacity: CGFloat
    let onDismiss: () -> Void
    
    // ✅ Card-level state
    @State private var timerCancellable: AnyCancellable?
    @State private var timerProgress: CGFloat = 0
    @State private var isMediaReady = false
    @State private var hasMarkedComplete = false
    @State private var isMuted = false
    
    // ✅ NEW: Dynamic duration tracking
    @State private var currentSlideDuration: TimeInterval = 5.0
    @State private var videoDurations: [String: TimeInterval] = [:] // Cache video durations
    @State private var slideStartTime: Date?
    
    // ✅ NEW: Video completion tracking
    @State private var videoCompletedNaturally = false
    
    private let defaultImageDuration: TimeInterval = 5.0
    private let timerInterval: TimeInterval = 0.05  // ✅ More granular for smoother progress
    
    private var isActive: Bool {
        manager.currentGroupIndex == groupIndex
    }
    
    private var currentSlideIndex: Int {
        min(Int(timerProgress), story.slides.count - 1)
    }
    
    private var currentSlide: StorySlide {
        story.slides[currentSlideIndex]
    }
    
    private var isCurrentSlideVideo: Bool {
        currentSlide.mediaType == .video
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                StoryMediaView(
                    slide: currentSlide,
                    isActive: isActive,
                    isPaused: manager.isPaused,
                    isMuted: isMuted,
                    onReady: {
                        handleMediaReady()
                    },
                    onVideoEnd: {
                        // ✅ CRITICAL: Video completed naturally
                        handleVideoCompletion()
                    },
                    onVideoDurationAvailable: { duration in
                        // ✅ NEW: Receive actual video duration from player
                        handleVideoDuration(duration, for: currentSlide.id)
                    }
                )
                .ignoresSafeArea()
                
                // ✅ CARD-LEVEL GESTURE: Tap zones for slide navigation
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleBackward()
                        }
                        .frame(width: proxy.size.width * 0.3)
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleForward()
                        }
                }
                .allowsHitTesting(dragOffsetOpacity > 0.9)
            }
            
            // ✅ UI Overlay with drag-based opacity
            .overlay(
                VStack(spacing: 4) {
                    StoryProgressBar(
                        slideCount: story.slides.count,
                        currentProgress: timerProgress
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    StoryHeader(
                        story: story,
                        showMuteButton: isCurrentSlideVideo,
                        isMuted: isMuted,
                        onMuteToggle: {
                            isMuted.toggle()
                        },
                        onClose: onDismiss,
                        opacity: dragOffsetOpacity
                    )
                    
                    Spacer()
                }
            )
            
            .rotation3DEffect(
                getAngle(proxy: proxy),
                axis: (x: 0, y: 1, z: 0),
                anchor: proxy.frame(in: .global).minX > 0 ? .leading : .trailing,
                perspective: 2.5
            )
        }
        .onAppear {
            guard !manager.isDismissing else { return }
            
            if timerProgress == 0 && !isMediaReady {
                resetStoryState(preserveMediaReady: false)
            }
            updateCurrentSlideDuration()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChangeCompat(of: manager.currentGroupIndex) { oldValue, newValue in
            guard !manager.isDismissing else {
                Logger.debug("⏸️ Ignoring group index change during dismissal")
                return
            }
            
            if newValue == groupIndex {
                let wasInactive = oldValue != groupIndex
                let shouldPreserveMedia = wasInactive && isMediaReady
                
                resetStoryState(preserveMediaReady: shouldPreserveMedia)
                updateCurrentSlideDuration()
                startTimer()
                manager.onGroupIndexChanged()
                
                Logger.debug("🔄 Story group \(groupIndex) activated")
            } else {
                stopTimer()
                Logger.debug("⏸️ Story group \(groupIndex) deactivated")
            }
        }
        .onChangeCompat(of: currentSlideIndex) { _, _ in
            // ✅ Update duration when slide changes
            updateCurrentSlideDuration()
            videoCompletedNaturally = false
        }
    }
    
    // MARK: - Media Event Handlers
    
    /// ✅ NEW: Handle media ready event
    private func handleMediaReady() {
        isMediaReady = true
        slideStartTime = Date()
        
        Logger.debug("✅ Media ready - Duration: \(currentSlideDuration)s")
    }
    
    /// ✅ NEW: Handle video completion
    private func handleVideoCompletion() {
        guard !manager.isDismissing else {
            Logger.debug("⏭️ Skipping advance - story is dismissing")
            return
        }
        
        guard !hasMarkedComplete else { return }
        
        videoCompletedNaturally = true
        
        Logger.info("🎬 Video completed naturally")
        
        // Advance to next slide or complete story
        if currentSlideIndex < story.slides.count - 1 {
            advanceToSlide(currentSlideIndex + 1)
        } else {
            markCompletedAndAdvance()
        }
    }
    
    /// ✅ NEW: Receive video duration from player
    private func handleVideoDuration(_ duration: TimeInterval, for slideId: String) {
        videoDurations[slideId] = duration
        
        // Update current duration if this is the active slide
        if currentSlide.id == slideId {
            currentSlideDuration = duration
            Logger.debug("📹 Video duration received: \(duration)s for slide \(slideId)")
        }
    }
    
    // MARK: - Duration Management
    
    /// ✅ NEW: Update duration for current slide
    private func updateCurrentSlideDuration() {
        let slide = currentSlide
        
        switch slide.mediaType {
        case .video:
            // Check if we have cached duration
            if let cachedDuration = videoDurations[slide.id] {
                currentSlideDuration = cachedDuration
                Logger.debug("📹 Using cached video duration: \(cachedDuration)s")
            } else {
                // Use default until we get actual duration from player
                currentSlideDuration = defaultImageDuration
                Logger.debug("📹 Waiting for video duration...")
            }
            
        case .image:
            // ✅ TODO: If server sends image duration, use it here
            // currentSlideDuration = slide.duration ?? defaultImageDuration
            currentSlideDuration = defaultImageDuration
            Logger.debug("🖼️ Using image duration: \(defaultImageDuration)s")
            
        case .none:
            currentSlideDuration = defaultImageDuration
        }
    }
    
    // MARK: - Timer Lifecycle
    
    private func startTimer() {
        guard !manager.isDismissing else {
            Logger.debug("⏸️ Skipping timer start - story is dismissing")
            return
        }
        
        stopTimer()
        slideStartTime = Date()
        
        Logger.debug("▶️ Starting timer for story group \(groupIndex) - Duration: \(currentSlideDuration)s")
        
        timerCancellable = Timer.publish(every: timerInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak manager] _ in
                guard let manager = manager else { return }
                
                // ✅ CRITICAL: Stop timer immediately if dismissing
                guard !manager.isDismissing else { return }
                guard manager.currentGroupIndex == groupIndex else { return }
                guard !manager.isPaused && isMediaReady else { return }
                guard !hasMarkedComplete else { return }
                
                // ✅ NEW: For videos that completed naturally, don't advance via timer
                if isCurrentSlideVideo && videoCompletedNaturally {
                    return
                }
                
                let slideIndex = currentSlideIndex
                
                // Mark slide as viewed at 50% completion
                let progressWithinSlide = timerProgress - CGFloat(slideIndex)
                if progressWithinSlide >= 0.5 && progressWithinSlide < 0.6 {
                    manager.markSlideViewed(
                        storyId: story.id,
                        slideId: story.slides[slideIndex].id,
                        campaignId: campaign.id
                    )
                }
                
                // Mark story complete when last slide reaches 90%
                if slideIndex == story.slides.count - 1 &&
                   progressWithinSlide >= 0.9 &&
                   !manager.isGroupViewed(story.id) {
                    manager.markGroupFullyViewed(storyId: story.id, campaignId: campaign.id)
                }
                
                // ✅ NEW: Use actual duration for progress calculation
                timerProgress += timerInterval / currentSlideDuration
                
                // Check if current slide is complete
                if timerProgress >= CGFloat(slideIndex + 1) {
                    if slideIndex < story.slides.count - 1 {
                        // Advance to next slide
                        advanceToSlide(slideIndex + 1)
                    } else {
                        // Story complete
                        markCompletedAndAdvance()
                    }
                }
            }
    }
    
    /// ✅ NEW: Advance to specific slide
    private func advanceToSlide(_ index: Int) {
        guard index < story.slides.count else { return }
        
        timerProgress = CGFloat(index)
        videoCompletedNaturally = false
        isMediaReady = false
        slideStartTime = Date()
        updateCurrentSlideDuration()
        
        Logger.debug("⏭️ Advanced to slide \(index)")
    }
    
    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        Logger.debug("⏹️ Timer stopped for story group \(groupIndex)")
    }
    
    private func resetStoryState(preserveMediaReady: Bool = false) {
        timerProgress = 0
        hasMarkedComplete = false
        videoCompletedNaturally = false
        slideStartTime = nil
        
        if !preserveMediaReady {
            isMediaReady = false
        }
        
        Logger.debug("🔄 Story state reset for group \(groupIndex) (preserving media: \(preserveMediaReady))")
    }
    
    // MARK: - Navigation Helpers
    
    private func handleBackward() {
        hasMarkedComplete = false
        videoCompletedNaturally = false
        
        let progressWithinSlide = timerProgress - CGFloat(currentSlideIndex)
        
        if progressWithinSlide < 0.3 && currentSlideIndex > 0 {
            // Go to previous slide
            advanceToSlide(currentSlideIndex - 1)
        } else if timerProgress < 1.0 {
            // Go to previous group
            moveToGroup(forward: false)
        } else {
            // Restart current slide
            advanceToSlide(currentSlideIndex)
        }
    }
    
    private func handleForward() {
        if currentSlideIndex >= story.slides.count - 1 {
            guard !hasMarkedComplete else { return }
            markCompletedAndAdvance()
        } else {
            advanceToSlide(currentSlideIndex + 1)
        }
    }
    
    private func markCompletedAndAdvance() {
        guard !manager.isDismissing else {
            Logger.debug("⏭️ Skipping advance - already dismissing")
            return
        }
        
        hasMarkedComplete = true
        manager.markGroupFullyViewed(storyId: story.id, campaignId: campaign.id)
        timerProgress = CGFloat(story.slides.count)
        moveToGroup(forward: true)
    }
    
    private func moveToGroup(forward: Bool) {
        guard !manager.isDismissing else {
            Logger.debug("⏭️ Skipping group navigation - dismissing")
            return
        }
        
        if !forward {
            if groupIndex > 0 {
                withAnimation {
                    manager.currentGroupIndex = groupIndex - 1
                }
            } else {
                advanceToSlide(0)
            }
        } else {
            if groupIndex < campaign.stories.count - 1 {
                withAnimation {
                    manager.currentGroupIndex = groupIndex + 1
                }
            } else {
                // ✅ CRITICAL: Stop timer BEFORE dismissing
                stopTimer()
                
                Logger.info("🏁 Reached end of story campaign - dismissing")
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    onDismiss()
                }
            }
        }
    }
    
    private func getAngle(proxy: GeometryProxy) -> Angle {
        let progress = proxy.frame(in: .global).minX / proxy.size.width
        let rotationAngle: CGFloat = 45
        return Angle(degrees: Double(rotationAngle * progress))
    }
}
