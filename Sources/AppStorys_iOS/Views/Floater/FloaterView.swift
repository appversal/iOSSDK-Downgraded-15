//
//  FloaterView.swift
//  AppStorys_iOS
//
//  Simple floating button anchored to bottom corners
//  ✅ ENHANCED: Support for Lottie animations
//

import SwiftUI
import UIKit
import Lottie

public struct FloaterView: View {
    // MARK: - Properties
    
    public let campaignId: String
    public let details: FloaterDetails
    
    @State private var isPresentedLinkError = false
    @State private var hasTrackedView = false
    @State private var contentLoaded = false
    
    private let padding: CGFloat = 16
    
    // MARK: - Computed Properties
    
    private var floaterWidth: CGFloat {
        CGFloat(details.width ?? 60)
    }
    
    private var floaterHeight: CGFloat {
        CGFloat(details.height ?? 60)
    }
    
    private var cornerRadius: CGFloat {
        let styling = details.styling
        
        // Try to get any corner radius value
        if let topLeft = styling?.topLeftRadius, !topLeft.isEmpty,
           let radius = Double(topLeft) {
            return CGFloat(radius)
        }
        if let topRight = styling?.topRightRadius, !topRight.isEmpty,
           let radius = Double(topRight) {
            return CGFloat(radius)
        }
        if let bottomLeft = styling?.bottomLeftRadius, !bottomLeft.isEmpty,
           let radius = Double(bottomLeft) {
            return CGFloat(radius)
        }
        if let bottomRight = styling?.bottomRightRadius, !bottomRight.isEmpty,
           let radius = Double(bottomRight) {
            return CGFloat(radius)
        }
        
        // Default to circular
        return min(floaterWidth, floaterHeight) / 2
    }
    
    private var isLeftPosition: Bool {
        details.position?.lowercased() == "left"
    }
    
    // MARK: - Initializer
    
    public init(campaignId: String, details: FloaterDetails) {
        self.campaignId = campaignId
        self.details = details
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack {
            Spacer()
            
            HStack {
                if isLeftPosition {
                    floaterButton
                    Spacer()
                } else {
                    Spacer()
                    floaterButton
                }
            }
            .padding(.horizontal, padding)
            .padding(.bottom, getSafeArea().bottom + padding)
        }
        .onAppear {
            trackViewIfNeeded()
        }
        .alert(isPresented: $isPresentedLinkError) {
            Alert(
                title: Text("Unable to open link"),
                message: Text("The link is invalid or cannot be opened."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Floater Button
    
    private var floaterButton: some View {
        Button(action: handleTap) {
            floaterContent
                .frame(width: floaterWidth, height: floaterHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Floater Content
    
    @ViewBuilder
    private var floaterContent: some View {
        // ✅ Priority: Lottie > Image > Placeholder
        if let lottieUrlString = details.lottieData, let lottieUrl = URL(string: lottieUrlString) {
            // Show Lottie animation
            FloaterLottieView(
                url: lottieUrl,
                contentLoaded: $contentLoaded
            )
        } else if let imageUrlString = details.image, let imageUrl = URL(string: imageUrlString) {
            // Show static image
            AppStorysImageView(
                url: imageUrl,
                contentMode: .fill,
                showShimmer: true,
                cornerRadius: cornerRadius,
                onSuccess: {
                    contentLoaded = true
                    Logger.debug("✅ Floater image loaded")
                },
                onFailure: { error in
                    Logger.warning("⚠️ Floater image failed: \(error.localizedDescription)")
                }
            )
        } else {
            // Show placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(.gray)
                )
        }
    }
    
    // MARK: - Actions
    private func handleTap() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            // Track analytics FIRST
            let contentType = details.lottieData != nil ? "lottie" : "image"
            await trackEvent(name: "clicked", metadata: [
                "content_type": contentType,
                "target": details.link ?? "nil"
            ])

            // Run Smart Link Handler on MainActor
            await MainActor.run {
                AppStorys.handleSmartLink(details.link)
            }
        }
    }

    private func openURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    if !success {
                        self.isPresentedLinkError = true
                        Logger.warning("⚠️ Failed to open URL: \(url.absoluteString)")
                    }
                    completion(success)
                }
            } else {
                self.isPresentedLinkError = true
                Logger.warning("⚠️ Cannot open URL: \(url.absoluteString)")
                completion(false)
            }
        }
    }

    
    // MARK: - Helpers
    
    private func getSafeArea() -> UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets ?? .zero
    }
    
    // MARK: - Tracking
    
    private func trackViewIfNeeded() {
        guard !hasTrackedView else { return }
        hasTrackedView = true
        
        let contentType = details.lottieData != nil ? "lottie" : "image"
        
        Task {
            await trackEvent(name: "viewed", metadata: [
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
}

// MARK: - Floater Lottie View Helper

private struct FloaterLottieView: UIViewRepresentable {
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
                    Logger.info("✅ Floater Lottie loaded and playing")
                }
            } catch {
                Logger.error("❌ Failed to load floater Lottie", error: error)
            }
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#if DEBUG
struct FloaterView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            VStack(spacing: 20) {
                Text("Left Position")
                FloaterView(
                    campaignId: "preview-left",
                    details: FloaterDetails(
                        id: "1",
                        image: "https://picsum.photos/60/60",
                        lottieData: nil,
                        link: "https://example.com",
                        height: 60,
                        width: 60,
                        position: "left",
                        styling: FloaterStyling(
                            topLeftRadius: "30",
                            topRightRadius: "30",
                            bottomLeftRadius: "30",
                            bottomRightRadius: "30"
                        )
                    )
                )
                
                Divider()
                
                Text("Right Position")
                FloaterView(
                    campaignId: "preview-right",
                    details: FloaterDetails(
                        id: "2",
                        image: "https://picsum.photos/60/60",
                        lottieData: nil,
                        link: "https://example.com",
                        height: 60,
                        width: 60,
                        position: "right",
                        styling: FloaterStyling(
                            topLeftRadius: "30",
                            topRightRadius: "30",
                            bottomLeftRadius: "30",
                            bottomRightRadius: "30"
                        )
                    )
                )
            }
        }
    }
}
#endif
