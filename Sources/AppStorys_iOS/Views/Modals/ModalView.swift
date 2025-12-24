//
//  ModalView.swift
//  AppStorys_iOS
//
//  ✅ ENHANCED: Support for Lottie animations in modals
//

import SwiftUI
import Lottie

public struct ModalView: View {
    
    let sdk: AppStorys
    let campaignId: String
    let details: ModalDetails
    
    // MARK: - State
    
    @State private var isVisible = false
    @State private var selectedModalIndex = 0
    @State private var hasTrackedView = false
    @State private var contentLoaded = false
    
    // Dismiss animation state
    @State private var isDismissing = false
    
    // MARK: - Initialization
    
    public init(sdk: AppStorys, campaignId: String, details: ModalDetails) {
        self.sdk = sdk
        self.campaignId = campaignId
        self.details = details
    }
    
    // MARK: - Body
    
    public var body: some View {
        if let modal = details.modals[safe: selectedModalIndex] {
            ZStack {
                // Backdrop with configurable opacity
                Color.black
                    .opacity(isDismissing ? 0 : modal.backdropOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        handleDismiss(reason: "backdrop_tap")
                    }
                    .animation(.easeOut(duration: 0.25), value: isDismissing)
                
                modalContent(modal)
                    .frame(width: modal.modalSize)
                    .clipShape(RoundedRectangle(cornerRadius: modal.cornerRadius, style: .continuous))
                    .overlay(
                        HStack {
                            Spacer()
                            closeButton
                        }
                            .offset(x: 8, y: -20)
                            .opacity(isVisible && !isDismissing ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.2).delay(0.3), value: isVisible),
                        alignment: .topLeading
                    )
                    .scaleEffect(scaleValue)
                    .opacity(opacityValue)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: isDismissing)
            }
            .onAppear {
                handleAppear()
            }
        } else {
            // Graceful degradation for empty modals array
            EmptyView()
                .onAppear {
                    Logger.error("❌ Modal campaign has no modal items")
                    
                    Task { [weak sdk] in
                        await sdk?.trackEvents(
                            eventType: "error",
                            campaignId: campaignId,
                            metadata: ["reason": "no_modal_items"]
                        )
                    }
                }
        }
    }
    
    // MARK: - Computed Animation Values
    
    private var scaleValue: CGFloat {
        if isDismissing {
            return 0.8
        }
        return isVisible ? 1.0 : 0.8
    }
    
    private var opacityValue: Double {
        if isDismissing {
            return 0.0
        }
        return isVisible ? 1.0 : 0.0
    }
    
    // MARK: - Modal Content
    
    @ViewBuilder
    private func modalContent(_ modal: ModalItem) -> some View {
        // ✅ Priority: Lottie > Image > Fallback
        if let lottieURL = modal.lottieURL {
            // Show Lottie animation
            ModalLottieView(
                url: lottieURL,
                modalId: modal.id,
                contentLoaded: $contentLoaded
            )
            .contentShape(Rectangle())
            .onTapGesture {
                handleModalTap(modal)
            }
        } else if let imageURL = modal.imageURL {
            // Show static image
            NormalImageView(
                url: imageURL,
                contentMode: .fit,
                showShimmer: true,
                cornerRadius: modal.cornerRadius,
                onSuccess: {
                    contentLoaded = true
                    Logger.debug("✅ Modal image loaded: \(modal.id)")
                },
                onFailure: { error in
                    Logger.error("❌ Modal image failed", error: error)
                    
                    Task { [weak sdk] in
                        await sdk?.trackEvents(
                            eventType: "image_load_failed",
                            campaignId: campaignId,
                            metadata: [
                                "modal_id": modal.id,
                                "url": imageURL.absoluteString
                            ]
                        )
                    }
                }
            )
            .onTapGesture {
                handleModalTap(modal)
            }
        } else {
            // Fallback for missing content
            fallbackView
        }
    }
    
    // MARK: - Fallback View
    
    private var fallbackView: some View {
        ZStack {
            Color.gray.opacity(0.1)
            
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("Content not available")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        Button(action: {
            handleDismiss(reason: "close_button")
        }) {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.thinMaterial))
        }
        .accessibilityLabel("Close modal")
        .accessibilityHint("Double tap to dismiss")
    }
    
    // MARK: - Actions
    
    private func handleAppear() {
        // Track view event once
        if !hasTrackedView {
            hasTrackedView = true
            
            let modal = details.modals[safe: selectedModalIndex]
            let contentType = modal?.lottieData != nil ? "lottie" : "image"
            
            Task { [weak sdk] in
                await sdk?.trackEvents(
                    eventType: "viewed",
                    campaignId: campaignId,
                    metadata: [
                        "modal_id": modal?.id ?? "unknown",
                        "content_type": contentType,
                        "screen": sdk?.currentScreen ?? "unknown"
                    ]
                )
            }
        }
        
        // Animate in with slight delay for better perception
        Task {
            await MainActor.run {
                withAnimation {
                    isVisible = true
                }
            }
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func handleModalTap(_ modal: ModalItem) {
        // ✅ Get the raw link string (not parsed URL)
        guard let linkValue = modal.link, !linkValue.isEmpty else {
            Logger.warning("⚠️ Modal '\(modal.id)' has no link configured")
            return
        }
        
        Logger.info("🔗 Modal tapped: \(modal.id) → \(linkValue)")
        
        let contentType = modal.lottieData != nil ? "lottie" : "image"
        
        // Track click
        Task { [weak sdk] in
            await sdk?.trackEvents(
                eventType: "clicked",
                campaignId: campaignId,
                metadata: [
                    "action": "modal_tap",
                    "modal_id": modal.id,
                    "content_type": contentType,
                    "content_loaded": contentLoaded,
                    "link": linkValue
                ]
            )
        }
        
        // ✅ Use smart link handler (supports URLs, campaign IDs, and trigger events)
        AppStorys.handleSmartLink(linkValue)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Dismiss after brief delay
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            await MainActor.run {
                handleDismiss(reason: "navigated")
            }
        }
    }
    
    private func handleDismiss(reason: String) {
        guard !isDismissing else {
            Logger.debug("⏭ Already dismissing")
            return
        }
        
        Logger.debug("❌ Dismissing modal: \(reason)")
        
        // Start dismiss animation
        isDismissing = true
        
        // Track dismissal
        Task { [weak sdk] in
            await sdk?.trackEvents(
                eventType: "dismissed",
                campaignId: campaignId,
                metadata: [
                    "reason": reason,
                    "modal_id": details.modals[safe: selectedModalIndex]?.id ?? "unknown"
                ]
            )
        }
        
        // Remove from SDK state after animation
        Task { [weak sdk] in
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s (match animation duration)
            await MainActor.run {
                sdk?.dismissCampaign(campaignId)
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Modal Lottie View Helper

private struct ModalLottieView: UIViewRepresentable {
    let url: URL
    let modalId: String
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
                    Logger.info("✅ Modal Lottie loaded: \(modalId)")
                }
            } catch {
                Logger.error("❌ Failed to load modal Lottie: \(modalId)", error: error)
            }
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // No updates needed
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview Support

#if DEBUG
//struct ModalView_Previews: PreviewProvider {
//    static var previews: some View {
//        let mockSDK = AppStorys.shared
//
//        let mockDetails = ModalDetails(
//            id: "preview-id",
//            modals: [
//                ModalItem(
//                    backgroundOpacity: "0.7",
//                    borderRadius: "24",
//                    link: "https://example.com",
//                    redirection: nil,
//                    size: "300",
//                    url: "https://picsum.photos/300/300",
//                    lottieData: nil
//                )
//            ],
//            name: "Preview"
//        )
//
//        ModalView(
//            sdk: mockSDK,
//            campaignId: "preview-campaign",
//            details: mockDetails
//        )
//    }
//}
#endif
