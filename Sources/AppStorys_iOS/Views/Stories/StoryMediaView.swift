//
//  StoryMediaView.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Pass video duration to parent for dynamic timing
//

import SwiftUI
import Kingfisher

/// Displays story media (image or video) with loading states and caching
struct StoryMediaView: View {
    let slide: StorySlide
    let onReady: () -> Void
    let onVideoEnd: () -> Void
    let onVideoDurationAvailable: (TimeInterval) -> Void  // ✅ NEW
    let isActive: Bool
    let isPaused: Bool
    let isMuted: Bool
    
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var videoURL: URL?
    
    // ✅ CRITICAL FIX: Store initial video URL without cache lookup in init
    init(
        slide: StorySlide,
        isActive: Bool = true,
        isPaused: Bool = false,
        isMuted: Bool = false,
        onReady: @escaping () -> Void,
        onVideoEnd: @escaping () -> Void,
        onVideoDurationAvailable: @escaping (TimeInterval) -> Void = { _ in }  // ✅ NEW with default
    ) {
        self.slide = slide
        self.isActive = isActive
        self.isPaused = isPaused
        self.isMuted = isMuted
        self.onReady = onReady
        self.onVideoEnd = onVideoEnd
        self.onVideoDurationAvailable = onVideoDurationAvailable

        if slide.mediaType == .video, let mediaURL = slide.mediaURL {
            if let cached = StoryCacheManager.shared.getCachedVideoURLSync(for: mediaURL) {
                _videoURL = State(initialValue: cached)
                _isLoading = State(initialValue: false)
            } else {
                _videoURL = State(initialValue: mediaURL)
                _isLoading = State(initialValue: true)
            }
        } else {
            _videoURL = State(initialValue: nil)
            _isLoading = State(initialValue: false)
        }
    }

    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch slide.mediaType {
            case .image:
                if let imageURL = slide.mediaURL {
                    KFImage(imageURL)
                        .placeholder {
                            loadingView
                        }
                        .onSuccess { _ in
                            isLoading = false
                            onReady()
                        }
                        .onFailure { error in
                            loadError = error
                            isLoading = false
                            Logger.error("❌ Failed to load story image", error: error)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    errorView
                }
                
            case .video:
                if let playerURL = videoURL {
                    StoryVideoPlayer(
                        url: playerURL,
                        onReady: {
                            isLoading = false
                            onReady()
                        },
                        onEnd: onVideoEnd,
                        onDurationAvailable: { duration in
                            // ✅ NEW: Forward duration to parent
                            onVideoDurationAvailable(duration)
                        },
                        isActive: isActive,
                        isPaused: isPaused,
                        isMuted: isMuted
                    )
                    .id(slide.id)
                    .overlay(
                        Group {
                            if isLoading {
                                loadingView
                            }
                        }
                    )
                    .onAppear {
                        loadCachedVideoURL()
                    }
                } else {
                    errorView
                }
                
            case .none:
                errorView
            }
            
            if let error = loadError {
                errorView
            }
        }
    }
    
    // ✅ Async cache lookup only on first appearance
    private func loadCachedVideoURL() {
        guard let originalURL = slide.mediaURL else { return }
        guard videoURL == originalURL else { return }
        
        Task {
            if let cached = StoryCacheManager.shared.getCachedVideoURLSync(for: originalURL) {
                Logger.debug("⚡ Using cached video: \(originalURL.lastPathComponent)")
                await MainActor.run {
                    videoURL = cached
                }
            } else {
                Logger.debug("📥 Video not cached, downloading: \(originalURL.lastPathComponent)")
                cacheVideoInBackground(url: originalURL)
            }
        }
    }
    
    private func cacheVideoInBackground(url: URL) {
        guard !StoryCacheManager.shared.isVideoCached(url: url) else { return }
        
        Task.detached(priority: .utility) {
            do {
                let cachedURL = try await StoryCacheManager.shared.cacheVideo(url: url)
                Logger.debug("✅ Video cached: \(url.lastPathComponent)")
                
                await MainActor.run {
                    videoURL = cachedURL
                }
            } catch {
                Logger.warning("⚠️ Background caching failed: \(url.lastPathComponent)")
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
//                .progressViewStyle(CircularProgressStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
    
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Failed to load media")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Kingfisher Configuration

extension KingfisherManager {
    static func configureForStories() {
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 150 * 1024 * 1024
        cache.memoryStorage.config.countLimit = 100
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(7)
        Logger.info("📦 Kingfisher cache configured for stories")
    }
}
