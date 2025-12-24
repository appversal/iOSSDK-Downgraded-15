//
//  AppStorysImageView.swift
//  AppStorys_iOS
//
//  Unified image loading component with Kingfisher + shimmer support
//  ✅ FIXED: Proper clipping to prevent TabView overlap during transitions
//

import SwiftUI
import Kingfisher

/// Unified image loading component for all campaigns
/// Provides consistent caching, loading states, and error handling
struct AppStorysImageView: View {
    // MARK: - Configuration
    
    let url: URL?
    let contentMode: SwiftUI.ContentMode
    let showShimmer: Bool
    let cornerRadius: CGFloat
    let onSuccess: (() -> Void)?
    let onFailure: ((Error) -> Void)?
    
    // MARK: - State
    
    @State private var isLoading = true
    @State private var loadFailed = false
    
    // MARK: - Initializer
    
    init(
        url: URL?,
        contentMode: SwiftUI.ContentMode = .fill,
        showShimmer: Bool = true,
        cornerRadius: CGFloat = 0,
        onSuccess: (() -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self.url = url
        self.contentMode = contentMode
        self.showShimmer = showShimmer
        self.cornerRadius = cornerRadius
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let url = url {
                    KFImage(url)
                        .placeholder { placeholderView }
                        .onSuccess { _ in
                            isLoading = false
                            loadFailed = false
                            onSuccess?()
                        }
                        .onFailure { error in
                            isLoading = false
                            loadFailed = true
                            Logger.error("❌ Failed to load image: \(url.absoluteString)", error: error)
                            onFailure?(error)
                        }
                    // ✅ ADD THIS: Enable GIF playback
                        .cacheOriginalImage()
                        .onProgress { receivedSize, totalSize in
                            // Optional: show loading progress for large GIFs
                        }
                        .resizable()
                        .aspectRatio(contentMode: contentMode == .fill ? .fill : .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    errorView
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .clipped()
    }
    
    // MARK: - Placeholder View
    
    @ViewBuilder
    private var placeholderView: some View {
        if showShimmer {
            ShimmerView()
        } else {
            Color.gray.opacity(0.2)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.title)
                )
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        Color.gray.opacity(0.1)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("Failed to load")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            )
    }
}

// MARK: - Kingfisher Configuration

extension KingfisherManager {
    /// Configure Kingfisher for optimal SDK performance
    static func configureForAppStorys() {
        let cache = ImageCache.default
        
        // Memory cache: 150MB, up to 100 images
        cache.memoryStorage.config.totalCostLimit = 150 * 1024 * 1024
        cache.memoryStorage.config.countLimit = 100
        
        // Disk cache: 500MB, 7 day expiration
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(7)
        
        // Downloader configuration
        let downloader = ImageDownloader.default
        downloader.downloadTimeout = 15.0  // 15 second timeout
        
        Logger.info("📦 Kingfisher configured for AppStorys SDK")
    }
    
    /// Clear all caches (useful for debugging or user-initiated cache clear)
    static func clearAllCaches() {
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache()
        Logger.info("🗑️ Kingfisher caches cleared")
    }
}

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var startPoint: UnitPoint = UnitPoint(x: -1.8, y: -1.2)
    @State private var endPoint: UnitPoint = UnitPoint(x: 0, y: -0.2)
    
    private let gradientColors = [
        Color.gray.opacity(0.2),
        Color.white.opacity(0.2),
        Color.gray.opacity(0.2)
    ]
    
    var body: some View {
        LinearGradient(colors: gradientColors, startPoint: startPoint, endPoint: endPoint)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                    startPoint = UnitPoint(x: 1, y: 1)
                    endPoint = UnitPoint(x: 2.2, y: 2.2)
                }
            }
    }
}

// MARK: - Specialized Shimmer Components

/// Widget card shimmer placeholder
struct WidgetShimmerView: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        ShimmerView()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Story thumbnail shimmer placeholder
struct StoryThumbnailShimmerView: View {
    let size: CGFloat
    
    var body: some View {
        ShimmerView()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

// MARK: - Preview Support

#if DEBUG
struct AppStorysImageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Valid URL with shimmer
            AppStorysImageView(
                url: URL(string: "https://picsum.photos/400/300"),
                contentMode: .fill,
                showShimmer: true,
                cornerRadius: 12
            )
            .frame(width: 300, height: 200)
            
            // Invalid URL - error state
            AppStorysImageView(
                url: URL(string: "https://invalid.url/image.jpg"),
                contentMode: .fill,
                cornerRadius: 12
            )
            .frame(width: 300, height: 200)
            
            // Nil URL - error state
            AppStorysImageView(
                url: nil,
                contentMode: .fill,
                cornerRadius: 12
            )
            .frame(width: 300, height: 200)
        }
        .padding()
    }
}
#endif
