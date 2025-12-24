//
//  AppStorysOverlayModifier.swift
//  AppStorys_iOS
//
//  ✅ SAFE: Crash-proof tooltip observer with dynamic SDK binding
//  ✅ FIXED: Bottom sheet dismissal with cached ID
//

import Combine
import SwiftUI

@MainActor
final class TooltipObserver: ObservableObject {
    @Published var manager: TooltipManager?
    private var sdkObserver: AnyCancellable?

    init(sdk: AppStorys) {
        self.manager = sdk.tooltipManager

        // ✅ Ensure subscription runs on main actor
        self.sdkObserver = sdk.$tooltipManager
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newManager in
                self?.manager = newManager
                Logger.debug("🎯 Tooltip observer updated — manager: \(newManager != nil)")
            }
    }
}

// MARK: - Main Modifier
struct AppStorysOverlayModifier: ViewModifier {
    @ObservedObject var sdk: AppStorys
    @StateObject private var tooltipObserver: TooltipObserver
    @StateObject private var transitionProgress = NavigationTransitionProgressPublisher.shared

    let showBanner: Bool
    let showFloater: Bool
    let showCSAT: Bool
    let showSurvey: Bool
    let showBottomSheet: Bool
    let showModal: Bool
    let showPIP: Bool
    let showStories: Bool
    let showTooltip: Bool
    let showCapture: Bool
    let showScratch: Bool
    let capturePosition: ScreenCaptureButton.Position

    @Namespace private var pipNamespace
    @State private var presentedBottomSheetCampaign: CampaignModel?
    @State private var cachedSheetId: String?
    @State private var hasHandledInitialState = false
    @State private var displayedScreenName: String?

    // ✅ NEW: Terms Sheet State
    @State private var scratchCardTermsHTML: String?
    @State private var showScratchTerms: Bool = false

    // MARK: - Init
    init(
        sdk: AppStorys,
        showBanner: Bool = true,
        showFloater: Bool = true,
        showCSAT: Bool = true,
        showSurvey: Bool = true,
        showBottomSheet: Bool = true,
        showModal: Bool = true,
        showPIP: Bool = true,
        showStories: Bool = true,
        showTooltip: Bool = true,
        showScratch: Bool = true,
        showCapture: Bool = true,
        capturePosition: ScreenCaptureButton.Position = .bottomCenter
    ) {
        self.sdk = sdk
        _tooltipObserver = StateObject(wrappedValue: TooltipObserver(sdk: sdk))
        self.showBanner = showBanner
        self.showFloater = showFloater
        self.showCSAT = showCSAT
        self.showSurvey = showSurvey
        self.showBottomSheet = showBottomSheet
        self.showModal = showModal
        self.showPIP = showPIP
        self.showStories = showStories
        self.showTooltip = showTooltip
        self.showCapture = showCapture
        self.showScratch = showScratch
        self.capturePosition = capturePosition
    }

    // MARK: - Core Body
    func body(content: Content) -> some View {
        ZStack {
            content
                .environmentObject(sdk)

            if sdk.currentScreen != nil {
                campaignOverlays
                    .opacity(overlayOpacity)
                    .animation(.linear(duration: 0.05), value: overlayOpacity)
            }
        }
        .animation(.easeInOut, value: sdk.storyPresentationState != nil)
        .task {
            await handleInitialBottomSheetState()
        }
        .onChangeCompat(of: sdk.activeBottomSheetCampaign) { oldValue, newValue in
            handleBottomSheetCampaignChange(from: oldValue, to: newValue)
        }
    }
    
    private var overlayOpacity: Double {
        guard transitionProgress.isTransitioning else { return 1.0 }
        switch transitionProgress.transitionType {
        case .gesture, .direct: return 1.0 - transitionProgress.progress
        case .none: return 1.0
        }
    }

    // MARK: - Overlays
    @ViewBuilder
    private var campaignOverlays: some View {
        // [Previous overlays: Banner, Floater, PIP, Tooltip, Modal, CSAT, Milestone... kept same]
        if showBanner, let bannerCampaign = sdk.activeBannerCampaign, case let .banner(details) = bannerCampaign.details {
            BannerView(campaignId: bannerCampaign.id, details: details)
                .transition(.move(edge: .top).combined(with: .opacity)).animation(.spring(response: 0.4), value: bannerCampaign.id).zIndex(800)
        }

        if showFloater, let floaterCampaign = sdk.activeFloaterCampaign, case let .floater(details) = floaterCampaign.details {
            FloaterView(campaignId: floaterCampaign.id, details: details)
                .transition(.scale.combined(with: .opacity)).animation(.spring(response: 0.3), value: floaterCampaign.id).zIndex(900)
        }

        if showPIP, let pipCampaign = sdk.activePIPCampaign {
            AppStorysPIPView(sdk: sdk, playerManager: sdk.pipPlayerManager, namespace: pipNamespace)
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity))).zIndex(1000).id(pipCampaign.id)
        }
        
        if showTooltip, sdk.isInitialized, let manager = tooltipObserver.manager {
            TooltipOverlayContainer(manager: manager).zIndex(3000)
        }
        
        if showModal, let modalCampaign = sdk.activeModalCampaign, case let .modal(details) = modalCampaign.details {
            ModalView(sdk: sdk, campaignId: modalCampaign.id, details: details)
                .transition(.opacity.combined(with: .scale)).animation(.spring(response: 0.4, dampingFraction: 0.8), value: modalCampaign.id).zIndex(1500)
        }

        if showCSAT, let csatCampaign = sdk.activeCSATCampaign, case let .csat(details) = csatCampaign.details {
            CSATView(sdk: sdk, campaignId: csatCampaign.id, details: details)
                .transition(.opacity.combined(with: .scale)).animation(.spring(response: 0.4), value: csatCampaign.id).zIndex(3200)
        }
        
        if let milestoneCampaign = sdk.activeMilestoneCampaign, case let .milestone(details) = milestoneCampaign.details, shouldShowAsOverlay(milestoneCampaign){
                VStack { Spacer(); MilestoneView(campaignId: milestoneCampaign.id, details: details).padding(.horizontal, 16).padding(.bottom, sdk.activeBannerCampaign != nil ? 140 : 20) }
                .zIndex(850).transition(.move(edge: .bottom).combined(with: .opacity)).id(milestoneCampaign.id)
            }
        
        // ✅ SCRATCH CARD OVERLAY (Updated)
        if showScratch,
           let scratchCampaign = sdk.activeScratchCampaign,
           case let .scratchCard(details) = scratchCampaign.details {

            ScratchCardView(
                campaignId: scratchCampaign.id,
                details: details,
                onShowTerms: { html in
                    // ✅ Show terms sheet via Overlay state
                    scratchCardTermsHTML = html
                    withAnimation(.easeIn(duration: 0.2)) {
                        showScratchTerms = true
                    }
                }
            ) {
                Logger.info("🎉 ScratchCard complete for campaign \(scratchCampaign.id)")
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.spring(response: 0.35), value: scratchCampaign.id)
            .zIndex(2500)
        }
        
        // ✅ TERMS SHEET OVERLAY (New)
        if showScratchTerms, let html = scratchCardTermsHTML {
            ScratchCardTermsSheet(
                htmlString: html,
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showScratchTerms = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scratchCardTermsHTML = nil
                    }
                }
            )
            .ignoresSafeArea()
            .zIndex(2600) // Above scratch card
        }
        
        // [Bottom Sheet, Capture, Story overlays... kept same]
        if showBottomSheet, let campaign = sdk.activeBottomSheetCampaign, case let .bottomSheet(details) = campaign.details {
            BottomSheetView(campaignId: campaign.id, details: details).ignoresSafeArea().zIndex(4000)
        }

        if showCapture, sdk.isScreenCaptureEnabled, let currentScreen = sdk.currentScreen, sdk.captureContextProvider.currentView != nil {
            ZStack(alignment: capturePosition.alignment) { Color.clear; sdk.captureButton().padding(capturePosition.padding) }
            .zIndex(999).transition(.scale.combined(with: .opacity)).animation(.spring(response: 0.3), value: sdk.isScreenCaptureEnabled)
        }

        if showStories, let presentationState = sdk.storyPresentationState {
            StoryGroupPager(manager: sdk.storyManager, campaign: presentationState.campaign, initialGroupIndex: presentationState.initialIndex, onDismiss: { sdk.dismissStory() })
            .zIndex(4000).id(presentationState.campaign.id).transition(.move(edge: .bottom))
        }
    }
    
    // [Keep existing Helper methods/structs...]
    private struct TooltipOverlayContainer: View {
        @ObservedObject var manager: TooltipManager
        @State private var isVisible = false
        var body: some View {
            ZStack { if isVisible { TooltipView(manager: manager).transition(.opacity.combined(with: .scale)).animation(.easeInOut(duration: 0.25), value: isVisible).id("tooltip_\(manager.currentStep)") } }
            .onReceive(manager.$isPresenting.receive(on: DispatchQueue.main)) { newValue in isVisible = newValue; Logger.debug("🎯 TooltipOverlayContainer — isPresenting changed to \(newValue)") }
        }
    }

    private func shouldShowAsOverlay(_ campaign: CampaignModel) -> Bool {
        guard let position = campaign.position, !position.isEmpty else { return true }
        return false
    }
    
    // [Keep all handleBottomSheet methods...]
    @MainActor private func handleInitialBottomSheetState() async {
        guard showBottomSheet, !hasHandledInitialState else { return }
        hasHandledInitialState = true
        if let campaign = sdk.activeBottomSheetCampaign, presentedBottomSheetCampaign == nil, !sdk.isCampaignDismissed(campaign.id) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            presentedBottomSheetCampaign = campaign
            cachedSheetId = campaign.id
        }
    }

    private func handleBottomSheetCampaignChange(from oldCampaign: CampaignModel?, to newCampaign: CampaignModel?) {
        guard showBottomSheet else { return }
        if let newCampaign = newCampaign {
            if presentedBottomSheetCampaign?.id == newCampaign.id {
                presentedBottomSheetCampaign = nil
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    presentedBottomSheetCampaign = newCampaign
                    cachedSheetId = newCampaign.id
                }
            } else {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    presentedBottomSheetCampaign = newCampaign
                    cachedSheetId = newCampaign.id
                }
            }
        } else {
            if presentedBottomSheetCampaign != nil { presentedBottomSheetCampaign = nil }
        }
    }

    private func handleSheetDismissal() {
        guard let campaignId = cachedSheetId else { return }
        sdk.dismissCampaign(campaignId)
        Task.detached(priority: .userInitiated) { await sdk.trackEvents(eventType: "dismissed", campaignId: campaignId, metadata: ["action": "swipe_dismiss"]) }
        cachedSheetId = nil
    }
}

// MARK: - New Terms Sheet Component
fileprivate struct ScratchCardTermsSheet: View {
    let htmlString: String
    let onDismiss: () -> Void
    
    @State private var isDismissing: Bool = false
    @State private var isPresented: Bool = false
    @State private var contentHeight: CGFloat = 0
    private let screenHeight: CGFloat = UIScreen.main.bounds.height

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .swipeDismissBackdrop(isDismissing: isDismissing)
                .onTapGesture { triggerDismiss("tap") }

            Group {
                if contentHeight > screenHeight {
                    ScrollView(showsIndicators: false) {
                        content
                    }
                    .overlay(closeButton, alignment: .topTrailing)
                } else {
                    VStack {
                        Spacer()
                        content
                            .overlay(closeButton, alignment: .topTrailing)
                    }
                }
            }
            .offset(y: (isPresented && !isDismissing) ? 0 : UIScreen.main.bounds.height)
            .onPreferenceChange(ViewHeightKey.self) { height in
                contentHeight = height
            }
            .swipeToDismiss(
                isPresented: $isPresented,
                isDismissing: $isDismissing,
                onDismiss: { _ in triggerDismiss("swipe") }
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = true
            }
        }
    }
    
    private func triggerDismiss(_ reason: String) {
        withAnimation(.easeOut(duration: 0.25)) { isDismissing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDismiss() }
    }

    private var content: some View {
        HTMLText(htmlString)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 32).fill(Color(.systemBackground)))
            .overlay(
                GeometryReader { proxy in
                    Color.clear.preference(key: ViewHeightKey.self, value: proxy.size.height)
                }
            )
    }

    private var closeButton: some View {
        Button(action: { triggerDismiss("close_button") }) {
            Image(systemName: "xmark").font(.headline).foregroundColor(.secondary)
                .frame(width: 40, height: 40).background(Circle().fill(.thinMaterial))
        }
        .padding()
    }
}
@MainActor
fileprivate struct ViewHeightKey: @MainActor PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Extension

extension View {
    public func withAppStorysOverlays(
        sdk: AppStorys = .shared,
        showBanner: Bool = true,
        showFloater: Bool = true,
        showCSAT: Bool = true,
        showSurvey: Bool = true,
        showBottomSheet: Bool = true,
        showModal: Bool = true,
        showPIP: Bool = true,
        showStories: Bool = true,
        showTooltip: Bool = true,
        showCapture: Bool = true,
        capturePosition: ScreenCaptureButton.Position = .bottomCenter
    ) -> some View {
        modifier(
            AppStorysOverlayModifier(
                sdk: sdk,
                showBanner: showBanner,
                showFloater: showFloater,
                showCSAT: showCSAT,
                showSurvey: showSurvey,
                showBottomSheet: showBottomSheet,
                showModal: showModal,
                showPIP: showPIP,
                showStories: showStories,
                showTooltip: showTooltip,
                showCapture: showCapture,
                capturePosition: capturePosition
            )
        )
    }
}
