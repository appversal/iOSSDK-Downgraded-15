//
//  ScratchCardView.swift
//  AppStorys_iOS
//

import SwiftUI
import UIKit

public struct ScratchCardView: View {
    // MARK: - Public API
    public let campaignId: String
    public let details: ScratchCardDetails
    public var onShowTerms: ((String) -> Void)? = nil  // ✅ NEW
    public var onComplete: (() -> Void)? = nil
    public var onDismiss: (() -> Void)? = nil
    
    // MARK: - State
    @State private var isVisible: Bool = true // ✅ Keep TRUE
    @State private var points: [CGPoint] = []
    @State private var touchedCells = Set<Int>()
    @State private var isRevealed: Bool = false
    @State private var hasTrackedView: Bool = false
    @State private var confettiTrigger: Int = 0
    @State private var showCopiedMessage: Bool = false
    
    // ✅ NEW: Animation coordination state
    @State private var isDismissing: Bool = false
    
    // Grid configuration
    private let gridCols = 20
    private let gridRows = 20
    private let defaultRevealThreshold: CGFloat = 0.07
    
    // MARK: - Computed Properties
    private var cardWidth: CGFloat { min(CGFloat(details.cardSize?.width ?? 260), UIScreen.main.bounds.width * 0.9) }
    private var cardHeight: CGFloat { min(CGFloat(details.cardSize?.height ?? 260), UIScreen.main.bounds.width * 0.9) }
    private var cornerRadius: CGFloat { CGFloat(details.cardSize?.cornerRadius ?? 32) }
    private var revealThreshold: CGFloat { defaultRevealThreshold }
    private var bgColor: Color { Color(hex: details.rewardContent?.backgroundColor ?? "#141414") }
    private var persistenceKey: String { "scratch_revealed_\(campaignId)" }
    private var isHapticsEnabled: Bool { details.interactions?.haptics == true }
    
    // MARK: - Init
    public init(
        campaignId: String,
        details: ScratchCardDetails,
        onShowTerms: ((String) -> Void)? = nil, // ✅ NEW
        onComplete: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.campaignId = campaignId
        self.details = details
        self.onShowTerms = onShowTerms
        self.onComplete = onComplete
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    public var body: some View {
        // ✅ Removed if isVisible wrapper
        content
            .onAppear {
                loadPersistedState()
                trackViewedIfNeeded()
                if let soundURL = details.soundFile {
                    Task { await CampaignAudioManager.shared.preloadSound(urlString: soundURL) }
                }
            }
    }
    
    // MARK: - Content
    private var content: some View {
        ZStack {
            // ✅ 1. Animated Backdrop
            Color.black
                .ignoresSafeArea()
                .swipeDismissBackdrop(isDismissing: isDismissing)
            
            // 2. Main Card Content
            VStack(spacing: 16) {
                Spacer(minLength: 20)
                headerView
                scratchCardView
                ctaSection
                Spacer(minLength: 20)
            }
            // ✅ 3. Swipe Gesture Handler (Offset removed, handled by modifier)
            .swipeToDismiss(
                isPresented: $isVisible,
                isDismissing: $isDismissing,
                onDismiss: { reason in
                    handleDismiss(reason: reason)
                }
            )
            .confettiCannon(counter: $confettiTrigger)
        }
        // ❌ NO TermsSheet here anymore
    }
    
    // MARK: - Header
    private var headerView: some View {
        ZStack {
            Rectangle().fill(Color.clear).frame(height: 64)
            
            Button { handleDismiss(reason: "close_button") } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.thinMaterial))
            }
        }
        .frame(height: 64)
    }
    
    // MARK: - Scratch Card
    private var scratchCardView: some View {
        ZStack {
            ZStack {
                if !isRevealed { overlayImageView }
                RewardContentView(
                    details: details,
                    reward: details.rewardContent,
                    cardHeight: cardHeight,
                    showCopiedMessage: $showCopiedMessage,
                    onCopy: { playHaptic() }
                )
                .frame(width: cardWidth, height: cardHeight)
                .background(bgColor)
                .mask { if isRevealed { Rectangle() } else { scratchMaskPath } }
                .gesture(scratchGesture)
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            copiedMessageOverlay
        }
    }
    
    @ViewBuilder private var overlayImageView: some View {
        if let overlayURLString = details.overlayImage, !overlayURLString.isEmpty, let overlayURL = URL(string: overlayURLString) {
            AppStorysImageView(url: overlayURL, contentMode: .fit, showShimmer: true)
                .frame(width: cardWidth, height: cardHeight).clipped()
        } else {
            Rectangle().fill(LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: cardWidth, height: cardHeight)
                .overlay(Text("Scratch here").font(.title2).foregroundColor(.white.opacity(0.5)))
        }
    }
    
    private var scratchMaskPath: some View {
        Path { path in
            if points.isEmpty { path.move(to: .zero) } else { path.addLines(points) }
        }
        .stroke(style: StrokeStyle(lineWidth: 50, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - CTA Section
    private var ctaSection: some View {
        ZStack {
            Rectangle().fill(Color.clear).frame(height: 80)
            VStack(spacing: 8) {
                if isRevealed {
                    if let cta = details.cta { ctaButton(cta: cta) }
                    if let terms = details.termsAndConditions, !terms.isEmpty {
                        termsButton(html: terms) // ✅ Pass HTML
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .frame(minHeight: 80)
    }
    
    private func ctaButton(cta: CTA) -> some View {
        HStack {
            Button(action: { handleCTATap(cta: cta) }) {
                Text(cta.buttonText ?? "Claim offer now")
                    .font(.system(size: cta.ctaFontSize?.cgFloatValue ?? 16, weight: .semibold))
                    .foregroundColor(Color(hex: cta.ctaTextColor ?? "#FFFFFF"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: cta.enableFullWidth == true ? .infinity : nil, minHeight: CGFloat(cta.height ?? 48))
                    .background(RoundedRectangle(cornerRadius: CGFloat(cta.borderRadius ?? 12), style: .continuous).fill(Color(hex: cta.buttonColor ?? "#007AFF")))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, CGFloat(cta.padding?.top ?? 0))
        .padding(.bottom, CGFloat(cta.padding?.bottom ?? 0))
        .padding(.leading, CGFloat(cta.padding?.left ?? 0))
        .padding(.trailing, CGFloat(cta.padding?.right ?? 0))
    }
    
    // ✅ UPDATED: termsButton calls onShowTerms
    private func termsButton(html: String) -> some View {
        Button {
            onShowTerms?(html)
        } label: {
            Text("Terms & Conditions*")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Gesture (Scratch)
    private var scratchGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in handleDragChanged(value) }
            .onEnded { _ in handleDragEnded() }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        guard !isRevealed else { return }
        let loc = CGPoint(x: min(max(0, value.location.x), cardWidth), y: min(max(0, value.location.y), cardHeight))
        points.append(loc)
        let idx = cellIndexFor(point: loc, in: CGSize(width: cardWidth, height: cardHeight))
        touchedCells.insert(idx)
        if CGFloat(touchedCells.count) / CGFloat(gridCols * gridRows) >= revealThreshold { reveal() }
    }
    
    private func handleDragEnded() {
        guard !isRevealed else { return }
        if CGFloat(touchedCells.count) / CGFloat(gridCols * gridRows) >= revealThreshold {
            reveal()
        } else if points.count > 1000 {
            points.removeFirst(points.count - 500)
        }
    }
    
    private func reveal() {
        guard !isRevealed else { return }
        withAnimation(.easeOut(duration: 0.35)) {
            isRevealed = true; points.removeAll(); touchedCells.removeAll(); confettiTrigger += 1
        }
        playHaptic()
        CampaignAudioManager.shared.playConfettiSound(soundURL: details.soundFile)
        UserDefaults.standard.set(true, forKey: persistenceKey)
        Task { await trackScratched() }
        onComplete?()
    }
    
    // MARK: - Dismiss
    private func handleDismiss(reason: String) {
        guard !isDismissing else { return }
        Logger.debug("❌ Dismissing scratch card: \(reason)")
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isDismissing = true
        }
        
        Task {
            await AppStorys.shared.trackEvents(
                eventType: "dismissed",
                campaignId: campaignId,
                metadata: ["reason": reason]
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isVisible = false
            AppStorys.shared.dismissCampaign(campaignId)
            onDismiss?()
        }
        
        playImpact()
    }
    
    // MARK: - CTA Logic
    private func handleCTATap(cta: CTA) {
        Task { await trackClicked(url: cta.url) }
        guard let link = cta.url, !link.trimmingCharacters(in: .whitespaces).isEmpty, let url = URL(string: link) else { return }
        openURL(url)
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run { handleDismiss(reason: "navigated") }
        }
    }
    
    private func openURL(_ url: URL) {
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) { UIApplication.shared.open(url) }
        }
        playImpact()
    }
    
    private var copiedMessageOverlay: some View {
        Group {
            if showCopiedMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Copied to clipboard").font(.footnote).fontWeight(.medium)
                }
                .padding(.horizontal).padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .offset(y: -cardHeight/2 - 50)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private func cellIndexFor(point: CGPoint, in size: CGSize) -> Int {
        guard size.width > 0, size.height > 0 else { return 0 }
        let col = Int((point.x / size.width) * CGFloat(gridCols))
        let row = Int((point.y / size.height) * CGFloat(gridRows))
        return min(max(row, 0), gridRows - 1) * gridCols + min(max(col, 0), gridCols - 1)
    }
    
    private func playHaptic() {
        if isHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    private func playImpact() {
        if isHapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    private func loadPersistedState() {
        if UserDefaults.standard.bool(forKey: persistenceKey) { isRevealed = true
        }
    }
    private func trackViewedIfNeeded() {
        if !hasTrackedView {
            hasTrackedView = true;
            Task {
                await AppStorys.shared.trackEvents(eventType: "viewed", campaignId: campaignId, metadata: nil)
            }
        }
    }
    private func trackScratched() async {
        await AppStorys.shared.trackEvents(eventType: "scratched", campaignId: campaignId, metadata: nil)
    }
    private func trackClicked(url: String?) async {
        await AppStorys.shared.trackEvents(eventType: "clicked", campaignId: campaignId, metadata: ["url": url ?? ""])
    }
}

// MARK: - Reward Content (Unchanged)
fileprivate struct RewardContentView: View {
    let details: ScratchCardDetails
    let reward: RewardContent?
    let cardHeight: CGFloat
    @Binding var showCopiedMessage: Bool
    let onCopy: () -> Void
    
    private var vSpacing: CGFloat { cardHeight * 0.04 }
    private var bannerPadding: CGFloat { cardHeight * 0.03 }
    private var contentPadding: CGFloat { cardHeight * 0.05 }

    var body: some View {
        let onlyImage = reward?.onlyImage ?? false
        ZStack {
            if onlyImage, let banner = details.bannerImage, let url = URL(string: banner) {
                AppStorysImageView(url: url, contentMode: .fill, showShimmer: true).clipped()
            } else {
                Color(hex: reward?.backgroundColor ?? "#FFFFFF")
            }
            
            if !onlyImage {
                VStack(alignment: .center, spacing: vSpacing) {
                    if let banner = details.bannerImage, let url = URL(string: banner) {
                        let imgSize = reward?.imageSize?.cgFloatValue ?? 96
                        AppStorysImageView(url: url, contentMode: .fill, showShimmer: true)
                            .clipShape(Circle()).frame(maxWidth: imgSize, maxHeight: imgSize)
                            .padding(.vertical, bannerPadding)
                    }

                    VStack(spacing: vSpacing) {
                        Text(reward?.brandName ?? "Special Offer")
                            .font(.system(size: reward?.titleFontSize?.cgFloatValue ?? 20, weight: .bold))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: reward?.offerTitleTextColor ?? "#000000"))
                            .multilineTextAlignment(.center)
                        Text(reward?.offerTitle ?? "Exclusive reward only for you")
                            .font(.system(size: reward?.subtitleFontSize?.cgFloatValue ?? 16))
                            .foregroundColor(Color(hex: reward?.offerSubtitleTextColor ?? "#666666"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    if let coupon = details.coupon, let code = coupon.code, !code.isEmpty {
                        couponButton(coupon: coupon, code: code).padding(.top,12)
                    }
                }
                .padding(.vertical, contentPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func couponButton(coupon: Coupon, code: String) -> some View {
        Button(action: { copyCouponCode(code) }) {
            HStack(spacing: 8) {
                Text(code).font(.system(.body, design: .monospaced)).fontWeight(.semibold)
                    .foregroundColor(Color(hex: coupon.codeTextColor ?? coupon.borderColor ?? "#FFFFFF"))
                Image(systemName: "doc.on.doc").font(.body)
                    .foregroundColor(Color(hex: coupon.codeTextColor ?? coupon.borderColor ?? "#FFFFFF")).padding(.leading, 8)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: coupon.backgroundColor ?? "#2C2C2E"))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: coupon.borderColor ?? "#FFFFFF").opacity(0.3), style: StrokeStyle(lineWidth: 1))))
        }
        .buttonStyle(.plain)
    }

    private func copyCouponCode(_ code: String) {
        UIPasteboard.general.string = code
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showCopiedMessage = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation(.easeOut(duration: 0.2)) { showCopiedMessage = false } }
        onCopy()
    }
}
