//
//  WidgetView.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Uses backend dimensions for precise aspect ratio
//  ✅ CLEAN: Removed dynamic sizing complexity
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
    
    private var imagePairs: [(first: WidgetImage, second: WidgetImage?)] {
        stride(from: 0, to: images.count, by: 2).map { index in
            let first = images[index]
            let second = images[safe: index + 1]
            return (first, second)
        }
    }
    
    // Radius & Margins
    private var topLeftRadius: CGFloat { radius(from: styling?.topLeftRadius) }
    private var topRightRadius: CGFloat { radius(from: styling?.topRightRadius) }
    private var bottomLeftRadius: CGFloat { radius(from: styling?.bottomLeftRadius) }
    private var bottomRightRadius: CGFloat { radius(from: styling?.bottomRightRadius) }
    
    private var topMargin: CGFloat { marginValue(from: styling?.topMargin) }
    private var bottomMargin: CGFloat { marginValue(from: styling?.bottomMargin) }
    private var leftMargin: CGFloat { marginValue(from: styling?.leftMargin) }
    private var rightMargin: CGFloat { marginValue(from: styling?.rightMargin) }
    
    // ✅ Aspect Ratio Calculation (Based on Backend)
    private var aspectRatio: CGFloat {
        guard let w = details.width, let h = details.height, w > 0, h > 0 else {
            return 9.0 / 16.0 // Default fallback if missing
        }
        return CGFloat(h) / CGFloat(w)
    }
    
    // ✅ Calculate exact container size
    private var calculatedContainerSize: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = screenWidth - leftMargin - rightMargin
        
        if details.type == "half" {
            let spacing: CGFloat = 8
            let cardWidth = (availableWidth - spacing) / 2
            let cardHeight = cardWidth * aspectRatio // Maintains backend ratio per card
            return CGSize(width: availableWidth, height: cardHeight)
        } else {
            let height = availableWidth * aspectRatio
            return CGSize(width: availableWidth, height: height)
        }
    }
    
    // MARK: - Initializer
    
    public init(campaignId: String, details: WidgetDetails) {
        self.campaignId = campaignId
        self.details = details
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 0) {
            contentView
                .frame(width: calculatedContainerSize.width, height: calculatedContainerSize.height)
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
        .padding(.top, topMargin)
        .padding(.bottom, bottomMargin)
        .padding(.leading, leftMargin)
        .padding(.trailing, rightMargin)
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
                    .frame(width: calculatedContainerSize.width, height: calculatedContainerSize.height)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            guard !isActive else { return }
            isActive = true
            handleCarouselAppear()
        }
        .onDisappear {
            isActive = false
            stopAutoScroll()
        }
        .onChangeCompat(of: currentIndex) { oldIndex, newIndex in
            handleIndexChange(from: oldIndex, to: newIndex)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded { _ in handleManualSwipe() }
        )
    }
    
    // MARK: - Half Width Layout
    
    private var halfWidthLayout: some View {
        let spacing: CGFloat = 8
        let cardWidth = (calculatedContainerSize.width - spacing) / 2
        let cardHeight = calculatedContainerSize.height
        
        return TabView(selection: $currentIndex) {
            ForEach(Array(imagePairs.enumerated()), id: \.offset) { pairIndex, pair in
                HStack(spacing: spacing) {
                    imageCard(for: pair.first)
                        .frame(width: cardWidth, height: cardHeight)
                    
                    if let second = pair.second {
                        imageCard(for: second)
                            .frame(width: cardWidth, height: cardHeight)
                    } else {
                        Color.clear
                            .frame(width: cardWidth, height: cardHeight)
                    }
                }
                .frame(width: calculatedContainerSize.width, height: calculatedContainerSize.height)
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
            guard !isActive else { return }
            isActive = true
            handleCarouselAppear()
        }
        .onDisappear {
            isActive = false
            stopAutoScroll()
        }
        .onChangeCompat(of: currentIndex) { oldIndex, newIndex in
            handleHalfWidthIndexChange(from: oldIndex, to: newIndex)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded { _ in handleManualSwipe() }
        )
    }
    
    // MARK: - Image Card
    
    @ViewBuilder
    private func imageCard(for widgetImage: WidgetImage) -> some View {
        Button(action: {
            handleTap(on: widgetImage)
        }) {
            if let lottieUrlString = widgetImage.lottieData, let lottieUrl = URL(string: lottieUrlString) {
                WidgetLottieView(url: lottieUrl, imageId: widgetImage.id)
            } else if let imageUrlString = widgetImage.image, let imageUrl = URL(string: imageUrlString) {
                AppStorysWidgetImageView(url: imageUrl, showShimmer: true)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
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
            .frame(height: 200)
    }
    
    // MARK: - Lifecycle & Actions
    
    private func handleCarouselAppear() {
        if details.type == "full", let first = images.first {
            trackViewedImageOnce(first.id)
        } else if details.type == "half", let firstPair = imagePairs.first {
            trackViewedImageOnce(firstPair.first.id)
            if let second = firstPair.second { trackViewedImageOnce(second.id) }
        }
        
        let pageCount = details.type == "full" ? images.count : imagePairs.count
        if pageCount > 1 { startAutoScroll() }
    }
    
    private func handleIndexChange(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex, let image = images[safe: newIndex] else { return }
        trackViewedImageOnce(image.id)
    }
    
    private func handleHalfWidthIndexChange(from oldIndex: Int, to newIndex: Int) {
        guard oldIndex != newIndex, let pair = imagePairs[safe: newIndex] else { return }
        trackViewedImageOnce(pair.first.id)
        if let second = pair.second { trackViewedImageOnce(second.id) }
    }
    
    private func handleManualSwipe() {
        stopAutoScroll()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            startAutoScroll()
        }
    }
    
    private func startAutoScroll() {
        let pageCount = details.type == "full" ? images.count : imagePairs.count
        guard pageCount > 1, isActive else { return }
        autoScrollTask?.cancel()
        
        autoScrollTask = Task { @MainActor in
            while !Task.isCancelled && isActive {
                isTransitioning = false
                progress = 0.0
                try? await Task.sleep(nanoseconds: 250_000_000)
                let startDate = Date()
                let animationInterval = autoScrollInterval - 0.3
                
                while Date().timeIntervalSince(startDate) < animationInterval {
                    guard !Task.isCancelled, isActive else { return }
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
    }
    
    private func stopAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        progress = 0.0
        isTransitioning = false
    }
    
    private func handleTap(on image: WidgetImage) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            let contentType = image.lottieData != nil ? "lottie" : "image"
            await trackEvent(name: "clicked", metadata: ["widget_image": image.id, "content_type": contentType, "target": image.link ?? "nil"])
            await MainActor.run { AppStorys.handleSmartLink(image.link) }
        }
    }
    
    private func trackViewedImageOnce(_ imageId: String) {
        guard !viewedImageIds.contains(imageId) else { return }
        viewedImageIds.insert(imageId)
        let widgetImage = images.first(where: { $0.id == imageId })
        let contentType = widgetImage?.lottieData != nil ? "lottie" : "image"
        Task { await trackEvent(name: "viewed", metadata: ["widget_image": imageId, "content_type": contentType]) }
    }
    
    private func trackEvent(name: String, metadata: [String: Any]? = nil) async {
        await AppStorys.shared.trackEvents(eventType: name, campaignId: campaignId, metadata: metadata)
    }
    
    // Style Helpers
    private func radius(from string: String?) -> CGFloat {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty, let d = Double(s) else { return 0 }
        return CGFloat(d)
    }
    
    private func marginValue(from string: String?) -> CGFloat {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty, let d = Double(s) else { return 0 }
        return CGFloat(d)
    }
    
    private var shouldShowProgressIndicators: Bool { details.type == "full" && images.count > 1 }
    private var shouldShowHalfWidthProgressIndicators: Bool { details.type == "half" && imagePairs.count > 1 }
}

// MARK: - Helpers

private struct WidgetLottieView: UIViewRepresentable {
    let url: URL
    let imageId: String
    func makeUIView(context: Context) -> LottieAnimationView {
        let v = LottieAnimationView()
        v.contentMode = .scaleAspectFit
        v.loopMode = .loop
        v.backgroundBehavior = .pauseAndRestore
        Task {
            do {
                let (d, _) = try await URLSession.shared.data(from: url)
                let a = try JSONDecoder().decode(LottieAnimation.self, from: d)
                await MainActor.run { v.animation = a; v.play() }
            } catch { Logger.error("❌ Lottie failed: \(imageId)", error: error) }
        }
        return v
    }
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {}
}

private extension Array {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
