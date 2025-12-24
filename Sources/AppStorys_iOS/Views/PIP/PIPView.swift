//
//  AppStorysPIPView.swift
//  AppStorys_iOS
//
//  UPDATED - Fixed isDragging state and expand condition
//

import SwiftUI
import AVKit

public struct AppStorysPIPView: View {
    // MARK: - Dependencies
    @ObservedObject private var sdk: AppStorys
    @ObservedObject private var playerManager: PIPPlayerManager
    
    let namespace: Namespace.ID
    
    // MARK: - State
    @State private var isExpanded = false
    @State private var isVisible = true
    @State private var isMuted = true
    
    // ✅ Simple flag: true = auto behavior, false = user controls
    @State private var isInitial = true
    
    // ✅ Observer for volume button changes
    @State private var muteObserver: NSKeyValueObservation?
    
    // Position state
    @State private var position: CGPoint = .zero
    @State private var isDragging = false
    
    // Gesture state for smooth tracking
    @GestureState private var dragState: CGSize = .zero
    
    // Track if position has been initialized
    @State private var isPositionInitialized = false
    
    // Track dismissal reason to prevent duplicate cleanup
    @State private var dismissalReason: DismissalReason?
    
    // Lifecycle monitoring
    @Environment(\.scenePhase) private var scenePhase
    @State private var isViewActive = true
    
    // Track if cleanup already happened
    @State private var hasCleanedUp = false
    
    @State private var currentScale: CGFloat = 1.0
    
    // Expanded view drag state
    @State private var expandedDragOffset: CGFloat = 0

    // MARK: - Configuration
    private let padding: CGFloat = 8
    
    // Dismissal reason enum
    enum DismissalReason {
        case userDismissed
        case navigation
        case appBackgrounded
    }
    
    // MARK: - Computed Properties
    private var videoWidth: CGFloat {
        CGFloat(pipDetails?.width ?? 140)
    }
    
    private var videoHeight: CGFloat {
        CGFloat(pipDetails?.height ?? 200)
    }
    
    // Calculate opacity based on drag offset (for expanded view)
    private var expandedDragOpacity: CGFloat {
        1.0 - min(abs(expandedDragOffset) / 500, 1.0)
    }
    
    private var pipDetails: PipDetails? {
        guard let campaign = sdk.pipCampaigns.first,
              case let .pip(details) = campaign.details else { return nil }
        return details
    }
    
    private var campaign: CampaignModel? {
        sdk.pipCampaigns.first
    }
    
    private var useSameVideo: Bool {
        pipDetails?.smallVideo == pipDetails?.largeVideo
    }
    
    // ✅ NEW: Check if expansion is allowed
    private var canExpand: Bool {
        guard let details = pipDetails else { return false }
        // Can expand if we have a large video OR if using same video
        return details.largeVideo != nil || useSameVideo
    }
    
    // MARK: - Initializer
    public init(
        sdk: AppStorys,
        playerManager: PIPPlayerManager,
        namespace: Namespace.ID
    ) {
        self.sdk = sdk
        self.playerManager = playerManager
        self.namespace = namespace
    }
    
    // MARK: - Body
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isVisible, let campaign = campaign, let details = pipDetails {
                    // Black background for expanded state
                    Color.black
                        .opacity(isExpanded ? expandedDragOpacity : 0)
                        .ignoresSafeArea()
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                    
                    // Video player that transitions between states
                    ZStack(alignment: .topLeading) {
                        VideoPlayer(player: playerManager.player)
                            .frame(
                                width: isExpanded ? geometry.size.width : videoWidth,
                                height: isExpanded ? geometry.size.height : videoHeight
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: isExpanded ? 0 : 16, style: .continuous)
                            )
                            .scaleEffect(currentScale)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentScale)
                            .allowsHitTesting(!isExpanded)
                        
                        // ✅ UPDATED: Only allow tap if can expand
                        Color.clear
                            .frame(
                                width: isExpanded ? geometry.size.width : videoWidth,
                                height: isExpanded ? geometry.size.height : videoHeight
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !isExpanded && !isDragging && canExpand {
                                    handleExpand()
                                }
                            }
                        
                        // Overlay controls with matched geometry
                        ZStack {
                            if isExpanded {
                                expandedControls(campaign: campaign, details: details)
                                    .transition(.opacity)
                            } else if !isDragging {
                                controlOverlay(campaign: campaign, details: details)
                                    .transition(.opacity)
                            }
                        }
                        .matchedGeometryEffect(id: "controls", in: namespace, isSource: true)
                    }
                    .position(
                        isExpanded
                            ? CGPoint(x: geometry.size.width / 2, y: (geometry.size.height / 2) + expandedDragOffset)
                            : calculateCurrentPosition(geometry: geometry)
                    )
                    .opacity(isExpanded ? expandedDragOpacity : 1.0)
                    .matchedGeometryEffect(id: "pipVideo", in: namespace)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                    .simultaneousGesture(
                        (isExpanded || !(pipDetails?.styling?.isMovable ?? false))
                            ? nil
                            : dragGesture(geometry)
                    )
                    .simultaneousGesture(isExpanded ? expandedDragGesture(campaign: campaign) : nil)
                    // ✅ UPDATED: Only allow tap if can expand
                    .onTapGesture {
                        if !isExpanded && !isDragging && canExpand {
                            handleExpand()
                        }
                    }
                    .onAppear {
                        setupVideo(campaign: campaign, details: details)
                    }
                }
            }
            .onAppear {
                if !isPositionInitialized {
                    setupInitialPosition(geometry: geometry)
                    isPositionInitialized = true
                }
                isViewActive = true
                hasCleanedUp = false
                Logger.debug("👀 PiP view appeared")
            }
            .onDisappear {
                handleViewDisappear()
            }
            .onChangeCompat(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            // ✅ Monitor player mute state to sync with volume buttons
            .onChangeCompat(of: playerManager.player.isMuted) { _, newValue in
                // Only sync if we're past initial state
                if !isInitial {
                    isMuted = newValue
                }
            }
        }
    }
    
    // MARK: - Drag Gesture
    private func dragGesture(_ geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($dragState) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !isDragging {
                    isDragging = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentScale = 0.9
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentScale = 1.0
                }
                handleDragEnd(value: value, geometry: geometry)
            }
    }
    
    // Drag gesture for expanded view (minimize on vertical drag down)
    private func expandedDragGesture(campaign: CampaignModel) -> some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                guard abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
                
                playerManager.pause()
                expandedDragOffset = value.translation.height
            }
            .onEnded { value in
                if expandedDragOffset > 150 {
                    handleMinimize()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        expandedDragOffset = 0
                    }
                }
                
                playerManager.play()
            }
    }
    
    // MARK: - Calculate Position
    private func calculateCurrentPosition(geometry: GeometryProxy) -> CGPoint {
        let currentX = position.x + dragState.width
        let currentY = position.y + dragState.height
        
        return CGPoint(
            x: clampX(currentX, geometry: geometry),
            y: clampY(currentY, geometry: geometry)
        )
    }
    
    private func clampX(_ x: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let minX = videoWidth / 2 + padding
        let maxX = geometry.size.width - videoWidth / 2 - padding
        return min(max(x, minX), maxX)
    }
    
    private func clampY(_ y: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let safeArea = getSafeArea()
        let minY = videoHeight / 2 + safeArea.top + padding
        let maxY = geometry.size.height - videoHeight / 2 - safeArea.bottom - padding
        return min(max(y, minY), maxY)
    }
    
    // MARK: - Expanded Controls
    @ViewBuilder
    private func expandedControls(campaign: CampaignModel, details: PipDetails) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: {
                    handleMuteToggle()
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .symbolRenderingMode(.hierarchical)
                        .symbolReplaceCompat()
                }
                .matchedGeometryEffect(id: "muteButton", in: namespace)
                
                Spacer()
                
                Button(action: {
                    handleMinimize()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                }
                .matchedGeometryEffect(id: "closeButton", in: namespace)
            }
            .padding(.horizontal)
            
            Spacer()
            
            if let link = details.link, let buttonText = details.buttonText,
               !buttonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    handleCTATap(campaign: campaign, link: link)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }) {
                    Text(buttonText)
                        .font(.headline)
                        .foregroundStyle(buttonTextColor(from: details.styling))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(buttonBackgroundColor(from: details.styling))
                        )
                }
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Control Overlay
    @ViewBuilder
    private func controlOverlay(campaign: CampaignModel, details: PipDetails) -> some View {
        VStack {
            HStack(spacing: 8) {
                Button(action: {
                    handleMuteToggle()
                }) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .symbolRenderingMode(.hierarchical)
                        .symbolReplaceCompat()
                }
                .matchedGeometryEffect(id: "muteButton", in: namespace)
                
                Spacer()
                
                Button(action: {
                    handleClose(campaign: campaign)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                }
                .matchedGeometryEffect(id: "closeButton", in: namespace)
            }
            .padding(8)
            Spacer()
        }
        .frame(width: videoWidth, height: videoHeight)
    }
    
    // MARK: - Gesture Handlers
    // ✅ FIXED: Always reset isDragging to false at the end
    private func handleDragEnd(value: DragGesture.Value, geometry: GeometryProxy) {
        guard pipDetails?.styling?.isMovable == true else {
            isDragging = false
            return
        }
        
        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
        let isQuickTap = dragDistance < 10
        
        if isQuickTap {
            isDragging = false
            // ✅ Only expand if allowed
            if canExpand {
                handleExpand()
            }
            return
        }
        
        let draggedX = position.x + value.translation.width
        let draggedY = position.y + value.translation.height
        
        let velocity = CGSize(
            width: value.predictedEndLocation.x - value.location.x,
            height: value.predictedEndLocation.y - value.location.y
        )
        
        let snappedPosition = calculateSnapPosition(
            currentPosition: CGPoint(x: draggedX, y: draggedY),
            velocity: velocity,
            geometry: geometry
        )
        
        position = snappedPosition
        isDragging = false  // ✅ FIXED: Reset isDragging here
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func calculateSnapPosition(
        currentPosition: CGPoint,
        velocity: CGSize,
        geometry: GeometryProxy
    ) -> CGPoint {
        
        guard pipDetails?.styling?.isMovable == true else {
            return position   // do not snap, keep fixed
        }

        let safeArea = getSafeArea()
        
        let leftEdge = videoWidth / 2 + padding
        let rightEdge = geometry.size.width - videoWidth / 2 - padding
        let topEdge = videoHeight / 2 + safeArea.top + padding
        let bottomEdge = geometry.size.height - videoHeight / 2 - safeArea.bottom - padding
        
        let finalX: CGFloat
        let finalY: CGFloat
        
        if abs(velocity.width) > 200 {
            finalX = velocity.width > 0 ? rightEdge : leftEdge
        } else {
            finalX = (abs(currentPosition.x - leftEdge) < abs(currentPosition.x - rightEdge))
            ? leftEdge : rightEdge
        }
        
        if abs(velocity.height) > 200 {
            finalY = velocity.height > 0 ? bottomEdge : topEdge
        } else {
            finalY = (abs(currentPosition.y - topEdge) < abs(currentPosition.y - bottomEdge))
            ? topEdge : bottomEdge
        }
        
        return CGPoint(x: finalX, y: finalY)
    }
    
    // MARK: - Lifecycle Handlers
    
    private func handleViewDisappear() {
        guard !hasCleanedUp else {
            Logger.debug("⏭️ Already cleaned up, skipping")
            return
        }
        
        Logger.debug("🔄 PiP view disappearing - cleaning up")
        
        hasCleanedUp = true
        isViewActive = false
        
        playerManager.cleanup()
        sdk.hidePIPCampaign()
        
        if let campaign = campaign, dismissalReason == nil {
            dismissalReason = .navigation
            
            Task {
                await sdk.trackEvents(
                    eventType: "dismissed",
                    campaignId: campaign.id,
                    metadata: ["reason": "navigation"]
                )
            }
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        guard isViewActive else { return }
        
        switch newPhase {
        case .background:
            Logger.debug("⏸️ App backgrounded - pausing PiP")
            playerManager.pause()
            
            if dismissalReason == nil {
                dismissalReason = .appBackgrounded
            }
            
        case .active:
            if oldPhase == .background || oldPhase == .inactive {
                Logger.debug("▶️ App foregrounded - resuming PiP")
                playerManager.play()
            }
            
        case .inactive:
            playerManager.pause()
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Actions
    private func setupVideo(campaign: CampaignModel, details: PipDetails) {
        guard let videoURL = details.smallVideo else { return }
        
        playerManager.updateVideoURL(videoURL)
        playerManager.play()
        
        // ✅ Always start muted in small PiP
        isMuted = true
        playerManager.player.isMuted = true
        isInitial = true
        
        Task {
            await sdk.trackEvents(eventType: "viewed", campaignId: campaign.id)
        }
    }
    
    // ✅ User tapped mute button - disable auto behavior
    private func handleMuteToggle() {
        isInitial = false
        isMuted.toggle()
        playerManager.player.isMuted = isMuted
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Logger.debug("🔊 User toggled mute: \(isMuted ? "muted" : "unmuted")")
    }
    
    private func handleExpand() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = true
        }
        
        if !useSameVideo, let largeVideo = pipDetails?.largeVideo {
            playerManager.updateVideoURL(largeVideo)
            playerManager.play()
        }
        
        // ✅ Only auto-unmute if still in initial state
        if isInitial {
            isInitial = false
            isMuted = false
            playerManager.player.isMuted = false
            Logger.debug("🔊 Auto-unmuted on first expand")
        } else {
            // Keep current state
            playerManager.player.isMuted = isMuted
            Logger.debug("🔊 Maintaining user preference: \(isMuted ? "muted" : "unmuted")")
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func handleMinimize() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = false
            expandedDragOffset = 0
        }
        
        if !useSameVideo, let smallVideo = pipDetails?.smallVideo {
            playerManager.updateVideoURL(smallVideo)
            playerManager.play()
        }
        
        // ✅ Always maintain current mute state
        playerManager.player.isMuted = isMuted
    }
    
    private func handleClose(campaign: CampaignModel) {
        guard dismissalReason == nil else {
            Logger.debug("⏭️ Already dismissed, ignoring")
            return
        }

        Logger.debug("❌ User dismissed PiP")
        dismissalReason = .userDismissed

        withAnimation {
            isVisible = false
        }

        sdk.dismissCampaign(campaign.id)

        Task.detached {
            await sdk.trackEvents(
                eventType: "clicked",
                campaignId: campaign.id,
                metadata: ["action": "close"]
            )
        }
    }
    
    private func handleCTATap(campaign: CampaignModel, link: String) {
        guard let url = URL(string: link) else { return }
        
        Task {
            await sdk.trackEvents(
                eventType: "clicked",
                campaignId: campaign.id,
                metadata: ["action": "cta"]
            )
        }
        
        UIApplication.shared.open(url)
    }
    
    // MARK: - Setup
    private func setupInitialPosition(geometry: GeometryProxy) {
        guard !isPositionInitialized, let details = pipDetails else { return }
        
        let safeArea = getSafeArea()
        
        let rightX = geometry.size.width - videoWidth / 2 - padding
        let leftX = videoWidth / 2 + padding
        let bottomY = geometry.size.height - videoHeight / 2 - safeArea.bottom - padding
        
        let x = (details.position?.lowercased() == "left") ? leftX : rightX
        
        position = CGPoint(x: x, y: bottomY)
        
        Logger.debug("📍 PiP initial position: (\(x), \(bottomY))")
    }
    
    private func getSafeArea() -> UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets ?? .zero
    }
    
    // MARK: - Helpers
    private func cornerRadius(from details: PipDetails) -> CGFloat {
        CGFloat(Double(details.styling?.cornerRadius ?? "24") ?? 24)
    }
    
    private func buttonBackgroundColor(from styling: PipStyling?) -> Color {
        guard let hex = styling?.ctaButtonBackgroundColor else { return .blue }
        return Color(hex: hex)
    }
    
    private func buttonTextColor(from styling: PipStyling?) -> Color {
        guard let hex = styling?.ctaButtonTextColor else { return .white }
        return Color(hex: hex)
    }
}
