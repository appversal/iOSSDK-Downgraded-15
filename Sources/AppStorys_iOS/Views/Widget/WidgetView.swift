//
//  WidgetView.swift
//  AppStorys_iOS
//
//  ✅ ENHANCED: Support for Lottie animations in widget images
//

import SwiftUI
import UIKit
import Kingfisher
import Lottie

// MARK: - Public Widget View

public struct WidgetView: View {
    // MARK: - Properties
    
    public let campaignId: String
    public let details: WidgetDetails
    
    @State private var currentIndex: Int = 0
    @State private var isPresentedLinkError: Bool = false
    @State private var autoScrollTask: Task<Void, Never>?
    @State private var progress: Double = 0.0
    @State private var isTransitioning: Bool = false
    @State private var viewedImageIds: Set<String> = []
    @State private var isActive = false
    private let autoScrollInterval: TimeInterval = 5.0
    
    // MARK: - Computed Properties
    
    private var images: [WidgetImage] {
        details.widgetImages ?? []
    }
    
    private var styling: WidgetStyling? {
        details.styling
    }
    
    // Group images into pairs for half-width layout
    private var imagePairs: [(first: WidgetImage, second: WidgetImage?)] {
        stride(from: 0, to: images.count, by: 2).map { index in
            let first = images[index]
            let second = images[safe: index + 1]
            return (first, second)
        }
    }
    
    private var topLeftRadius: CGFloat {
        radius(from: styling?.topLeftRadius)
    }

    private var topRightRadius: CGFloat {
        radius(from: styling?.topRightRadius)
    }

    private var bottomLeftRadius: CGFloat {
        radius(from: styling?.bottomLeftRadius)
    }

    private var bottomRightRadius: CGFloat {
        radius(from: styling?.bottomRightRadius)
    }
        
    private var heightValue: CGFloat {
        calculateHeight()
    }
    
    // MARK: - Initializer
    
    public init(campaignId: String, details: WidgetDetails) {
        self.campaignId = campaignId
        self.details = details
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 8) {
            contentView
                .frame(height: heightValue)
                .overlay(
                    Group {
                        if shouldShowProgressIndicators {
                            progressIndicators(count: images.count)
                                .padding(.bottom, 8)
                        }
                    },
                    alignment: .bottom
                )
        }
        .padding(.top, marginValue(from: styling?.topMargin))
        .padding(.bottom, marginValue(from: styling?.bottomMargin))
        .padding(.leading, marginValue(from: styling?.leftMargin))
        .padding(.trailing, marginValue(from: styling?.rightMargin))
        .alert(isPresented: $isPresentedLinkError) {
            Alert(
                title: Text("Unable to open link"),
                message: Text("The link is invalid or cannot be opened."),
                dismissButton: .default(Text("OK"))
            )
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        if images.isEmpty {
            emptyStateView
        } else if details.type == "full" {
            fullWidthCarousel
        } else if details.type == "half" {
            halfWidthLayout
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Full Width Carousel
    
    private var fullWidthCarousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(images.enumerated()), id: \.element.id) { idx, widgetImage in
                imageCard(for: widgetImage)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            guard !isActive else { return } // ✅ Prevent double start
            isActive = true
            handleCarouselAppear()
        }
        .onDisappear {
            isActive = false // ✅ Mark inactive
            stopAutoScroll()
        }
        .onChangeCompat(of: currentIndex) { oldIndex, newIndex in
            handleIndexChange(from: oldIndex, to: newIndex)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { _ in
                    handleManualSwipe()
                }
        )
    }
    
    // MARK: - Half Width Layout
    
    private var halfWidthLayout: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(imagePairs.enumerated()), id: \.offset) { pairIndex, pair in
                HStack{
                    imageCard(for: pair.first)
                        .frame(maxWidth: .infinity)
                    
                    if let second = pair.second {
                        imageCard(for: second)
                            .frame(maxWidth: .infinity)
                    }
                }
                .tag(pairIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(
            Group {
                if shouldShowHalfWidthProgressIndicators {
                    progressIndicators(count: imagePairs.count)
                        .padding(.bottom, 8)
                }
            },
            alignment: .bottom
        )
        .onAppear {
            guard !isActive else { return } // ✅ Prevent double start
            isActive = true
            handleCarouselAppear()
        }
        .onDisappear {
            isActive = false // ✅ Mark inactive
            stopAutoScroll()
        }
        .onChangeCompat(of: currentIndex) { oldIndex, newIndex in
            handleHalfWidthIndexChange(from: oldIndex, to: newIndex)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { _ in
                    handleManualSwipe()
                }
        )
    }
    
    // MARK: - Image Card
    
    @ViewBuilder
    private func imageCard(for widgetImage: WidgetImage) -> some View {
        Button(action: {
            handleTap(on: widgetImage)
        }) {
            // ✅ Priority: Lottie > Image > Placeholder
            if let lottieUrlString = widgetImage.lottieData, let lottieUrl = URL(string: lottieUrlString) {
                // Show Lottie animation
                WidgetLottieView(url: lottieUrl, imageId: widgetImage.id)
//                    .clipShape(UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous))
            } else if let imageUrlString = widgetImage.image, let imageUrl = URL(string: imageUrlString) {
                // Show static image
                AppStorysImageView(
                    url: imageUrl,
                    contentMode: .fit,
                    showShimmer: true,
                    cornerRadius: 0,
                    onSuccess: {
                        Logger.debug("✅ Widget image loaded: \(widgetImage.id)")
                    },
                    onFailure: { error in
                        Logger.warning("⚠️ Widget image failed: \(widgetImage.id)")
                    }
                )
//                .clipShape(UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous))
            } else {
                // Show placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
//                    .clipShape(UnevenRoundedRectangle(cornerRadii: cornerRadii, style: .continuous))
            }
        }
        .clipUnevenRounded(
            topLeft: topLeftRadius,
            topRight: topRightRadius,
            bottomLeft: bottomLeftRadius,
            bottomRight: bottomRightRadius
        )
        .buttonStyle(.plain)
    }
    
    // MARK: - Progress Indicators
    
    @ViewBuilder
    private func progressIndicators(count: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                progressIndicator(for: index, isActive: index == currentIndex)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Capsule(style: .continuous).fill(.thinMaterial))
    }
    
    @ViewBuilder
    private func progressIndicator(for index: Int, isActive: Bool) -> some View {
        let indicatorWidth: CGFloat = isActive ? 24 : 8
        
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(.secondary)
                .frame(width: indicatorWidth, height: 8)
            
            if isActive && !isTransitioning {
                Capsule(style: .continuous)
                    .fill(.white)
                    .frame(width: indicatorWidth * CGFloat(progress), height: 8)
                    .animation(.linear(duration: 0.1), value: progress)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isActive)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No widget content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleCarouselAppear() {
        // Track first visible image(s)
        if details.type == "full" {
            if let firstImage = images.first {
                trackViewedImageOnce(firstImage.id)
            }
        } else if details.type == "half" {
            if let firstPair = imagePairs.first {
                trackViewedImageOnce(firstPair.first.id)
                if let second = firstPair.second {
                    trackViewedImageOnce(second.id)
                }
            }
        }
        
        // Start auto-scroll if multiple pages
        let pageCount = details.type == "full" ? images.count : imagePairs.count
        if pageCount > 1 {
            startAutoScroll()
        }
    }
    
    private func handleIndexChange(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex, let image = images[safe: newIndex] else { return }
        trackViewedImageOnce(image.id)
    }
    
    private func handleHalfWidthIndexChange(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex, let pair = imagePairs[safe: newIndex] else { return }
        
        trackViewedImageOnce(pair.first.id)
        if let second = pair.second {
            trackViewedImageOnce(second.id)
        }
    }
    
    private func handleManualSwipe() {
        Logger.debug("👆 Manual swipe detected - resetting timer")
        
        stopAutoScroll()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            startAutoScroll()
        }
    }
    
    // MARK: - Auto-Scroll Logic
    
    private func startAutoScroll() {
        let pageCount = details.type == "full" ? images.count : imagePairs.count
        guard pageCount > 1, isActive else { return } // ✅ Check isActive
        
        // ✅ Cancel any existing task first
        autoScrollTask?.cancel()
        
        autoScrollTask = Task { @MainActor in
            while !Task.isCancelled && isActive { // ✅ Check isActive in loop
                isTransitioning = false
                progress = 0.0
                
                try? await Task.sleep(nanoseconds: 250_000_000)
                
                let startDate = Date()
                let animationInterval = autoScrollInterval - 0.3
                
                while Date().timeIntervalSince(startDate) < animationInterval {
                    guard !Task.isCancelled, isActive else { return } // ✅ Check isActive
                    
                    let elapsed = Date().timeIntervalSince(startDate)
                    progress = min(1.0, elapsed / animationInterval)
                    
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
                
                isTransitioning = true
                progress = 1.0
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = (currentIndex + 1) % pageCount
                }
                
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        
        Logger.debug("▶️ Auto-scroll started for widget: \(campaignId)")
    }
    
    private func stopAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        progress = 0.0
        isTransitioning = false
        
        Logger.debug("⏸️ Auto-scroll stopped for widget: \(campaignId)")
    }

    
    // MARK: - Actions
    private func handleTap(on image: WidgetImage) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            let contentType = image.lottieData != nil ? "lottie" : "image"
            await trackEvent(name: "clicked", metadata: [
                "widget_image": image.id,
                "content_type": contentType,
                "target": image.link ?? "nil"
            ])

            // Execute Smart Link / Event logic
            await MainActor.run {
                AppStorys.handleSmartLink(image.link)
            }
        }
    }
    
    private func openURL(_ url: URL) {
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        isPresentedLinkError = true
                        Logger.warning("⚠️ Failed to open URL: \(url.absoluteString)")
                    }
                }
            } else {
                isPresentedLinkError = true
                Logger.warning("⚠️ Cannot open URL: \(url.absoluteString)")
            }
        }
    }
    
    // MARK: - Tracking Helper
    
    private func trackViewedImageOnce(_ imageId: String) {
        guard !viewedImageIds.contains(imageId) else { return }
        
        viewedImageIds.insert(imageId)
        
        // Determine content type for tracking
        let widgetImage = images.first(where: { $0.id == imageId })
        let contentType = widgetImage?.lottieData != nil ? "lottie" : "image"
        
        Task {
            await trackEvent(name: "viewed", metadata: [
                "widget_image": imageId,
                "content_type": contentType
            ])
        }
    }
    
    private func trackEvent(name: String, metadata: [String: Any]? = nil) async {
        await AppStorys.shared.trackEvents(
            eventType: name,
            campaignId: campaignId,
            metadata: metadata
        )
    }
    
    // MARK: - Layout Calculations
    
    private func calculateHeight() -> CGFloat {
        guard let width = details.width,
              let height = details.height,
              width > 0, height > 0 else {
            return 200
        }
        
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding = marginValue(from: styling?.leftMargin) +
                                marginValue(from: styling?.rightMargin)
        let availableWidth = screenWidth - horizontalPadding
        
        let aspectRatio = CGFloat(height) / CGFloat(width)
        let calculatedHeight = availableWidth * aspectRatio
        
        return min(max(calculatedHeight, 150), 400)
    }
    
    // MARK: - Style Helpers
    
    private func radius(from string: String?) -> CGFloat {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let doubleVal = Double(s) else {
            return 0
        }
        return CGFloat(doubleVal)
    }
    
    private func marginValue(from string: String?) -> CGFloat {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let doubleVal = Double(s) else {
            return 0
        }
        return CGFloat(doubleVal)
    }
    
    // MARK: - Computed Flags
    
    private var shouldShowProgressIndicators: Bool {
        details.type == "full" && images.count > 1
    }
    
    private var shouldShowHalfWidthProgressIndicators: Bool {
        details.type == "half" && imagePairs.count > 1
    }
}

// MARK: - Widget Lottie View Helper

private struct WidgetLottieView: UIViewRepresentable {
    let url: URL
    let imageId: String
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Load animation from URL
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let animation = try JSONDecoder().decode(LottieAnimation.self, from: data)
                
                await MainActor.run {
                    animationView.animation = animation
                    animationView.play()
                    Logger.info("✅ Widget Lottie loaded: \(imageId)")
                }
            } catch {
                Logger.error("❌ Failed to load widget Lottie: \(imageId)", error: error)
            }
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // No updates needed
    }
}

// MARK: - Safe Array Extension

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
