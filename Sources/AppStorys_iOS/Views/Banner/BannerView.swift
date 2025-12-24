//
//  BannerView.swift
//  AppStorys_iOS
//
//  Simplified banner campaign view with bottom positioning
//  ✅ UPDATED: Support for Lottie animations + AppStorysImageView + Smart Link Handler
//

import SwiftUI
import Lottie

struct BannerView: View {
    let campaignId: String
    let details: BannerDetails
    
    @State private var isVisible = true
    @State private var hasTrackedView = false
    @State private var contentLoaded = false
    
    var body: some View {
        if isVisible {
            VStack {
                bannerContent
                
                .onTapGesture {
                    handleTap()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            .padding(.bottom, bottomPadding)
            .padding(.horizontal, horizontalPadding)
            
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
            .onAppear {
                trackViewIfNeeded()
            }
        }
    }
    
    @ViewBuilder
    private var bannerContent: some View {
        ZStack(alignment: .topTrailing) {
            // ✅ Priority: Lottie > Image > Placeholder
            if let lottieUrlString = details.lottieData, let lottieUrl = URL(string: lottieUrlString) {
                // Show Lottie animation
                LottieView(url: lottieUrl, contentLoaded: $contentLoaded)
                    .frame(height: bannerHeight)
                    .clipUnevenRounded(
                        topLeft: topLeftRadius,
                        topRight: topRightRadius,
                        bottomLeft: bottomLeftRadius,
                        bottomRight: bottomRightRadius
                    )
                    .onTapGesture {
                        handleTap()
                    }
            } else if let imageUrlString = details.image, let imageUrl = URL(string: imageUrlString) {
                // Show static image
                AppStorysImageView(
                    url: imageUrl,
                    contentMode: .fill,
                    showShimmer: true,
                    cornerRadius: 0,
                    onSuccess: {
                        contentLoaded = true
                        Logger.info("✅ Banner image loaded: \(campaignId)")
                    },
                    onFailure: { error in
                        Logger.error("❌ Banner image failed to load: \(campaignId)", error: error)
                    }
                )
                .frame(height: bannerHeight)
                .clipUnevenRounded(
                    topLeft: topLeftRadius,
                    topRight: topRightRadius,
                    bottomLeft: bottomLeftRadius,
                    bottomRight: bottomRightRadius
                )
                .onTapGesture {
                    handleTap()
                }
            } else {
                // Show placeholder
                placeholderView
                    .clipUnevenRounded(
                        topLeft: topLeftRadius,
                        topRight: topRightRadius,
                        bottomLeft: bottomLeftRadius,
                        bottomRight: bottomRightRadius
                    )
            }
            
            if details.styling?.enableCloseButton == true {
                closeButton
                    .padding(8)
            }
        }
    }
    
    private var bannerHeight: CGFloat {
        guard let w = details.width, let h = details.height, w > 0 else {
            return 120
        }
        
        let screenWidth = UIScreen.main.bounds.width - (horizontalPadding * 2)
        let scale = screenWidth / CGFloat(w)
        return CGFloat(h) * scale
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 120)
            .overlay(
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            )
    }
    
    private var closeButton: some View {
        Button(action: handleDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, .black.opacity(0.6))
        }
    }
    
    // MARK: - Layout Calculations
    
    private var horizontalPadding: CGFloat {
        let left = parseMargin(details.styling?.marginLeft) ?? 16
        let right = parseMargin(details.styling?.marginRight) ?? 16
        return max(left, right)
    }
    
    private var bottomPadding: CGFloat {
        parseMargin(details.styling?.marginBottom) ?? 60
    }
    
    private var topLeftRadius: CGFloat {
        parseRadius(details.styling?.topLeftRadius) ?? 12
    }
    
    private var topRightRadius: CGFloat {
        parseRadius(details.styling?.topRightRadius) ?? 12
    }
    
    private var bottomLeftRadius: CGFloat {
        parseRadius(details.styling?.bottomLeftRadius) ?? 12
    }
    
    private var bottomRightRadius: CGFloat {
        parseRadius(details.styling?.bottomRightRadius) ?? 12
    }
    
    private func parseMargin(_ value: StringOrInt?) -> CGFloat? {
        guard let value = value else { return nil }
        return CGFloat(Double(value.stringValue) ?? 0)
    }

    private func parseRadius(_ value: StringOrInt?) -> CGFloat? {
        guard let value = value else { return nil }
        return CGFloat(Double(value.stringValue) ?? 0)
    }
    
    // MARK: - Actions

    private func handleTap() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        Logger.info("🎯 Banner tapped: \(campaignId)")
        
        Task {
            // Track analytics FIRST
            let contentType = details.lottieData != nil ? "lottie" : "image"
            await trackEvent(name: "clicked", metadata: [
                "action": "banner_tap",
                "content_type": contentType,
                "target": details.link ?? "nil"
            ])
            
            // Run Smart Link Handler on MainActor
            await MainActor.run {
                AppStorys.handleSmartLink(details.link)
            }
        }
    }
    
    private func handleDismiss() {
        Logger.info("🚫 Banner dismissed: \(campaignId)")
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        Task {
            await trackEvent(name: "dismissed", metadata: ["action": "user_dismiss"])
            
            await MainActor.run {
                AppStorys.shared.dismissCampaign(campaignId)
            }
        }
    }
    
    // MARK: - Tracking
    
    private func trackViewIfNeeded() {
        guard !hasTrackedView else { return }
        hasTrackedView = true
        
        Task {
            await trackEvent(name: "viewed")
        }
    }
    
    private func trackEvent(name: String, metadata: [String: Any]? = nil) async {
        var eventMetadata = metadata ?? [:]
        eventMetadata["position"] = "bottom"
        eventMetadata["has_close_button"] = details.styling?.enableCloseButton ?? false
        eventMetadata["content_loaded"] = contentLoaded
        
        // Only add content_type if not already present (for click events)
        if eventMetadata["content_type"] == nil {
            eventMetadata["content_type"] = details.lottieData != nil ? "lottie" : "image"
        }
        
        await AppStorys.shared.trackEvents(
            eventType: name,
            campaignId: campaignId,
            metadata: eventMetadata
        )
    }
}

// MARK: - Lottie View Helper
private struct LottieView: UIViewRepresentable {
    let url: URL
    @Binding var contentLoaded: Bool
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.contentMode = .scaleAspectFill
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
                    contentLoaded = true
                    Logger.info("✅ Banner Lottie loaded and playing")
                }
            } catch {
                Logger.error("❌ Failed to load Lottie animation", error: error)
            }
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // No updates needed
    }
}
