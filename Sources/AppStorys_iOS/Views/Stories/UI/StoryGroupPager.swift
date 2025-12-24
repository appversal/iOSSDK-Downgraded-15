//
//  StoryGroupPager.swift
//  AppStorys_iOS
//
//  Fixed: Moved viewer-level gestures to pager (proper separation of concerns)
//  ✅ FIXED: dismisses view if stuck during swipe-down
//

import SwiftUI

/// Full-screen pager that displays all story groups in a campaign
struct StoryGroupPager: View {
    @ObservedObject var manager: StoryManager
    let campaign: StoryCampaign
    let initialGroupIndex: Int
    let onDismiss: () -> Void
    
    // ✅ Viewer-level state (moved from StoryCardView)
    @State private var viewerDragOffset: CGFloat = 0
    
    var body: some View {
        TabView(selection: $manager.currentGroupIndex) {
            ForEach(Array(campaign.stories.enumerated()), id: \.element.id) { index, story in
                StoryCardView(
                    manager: manager,
                    campaign: campaign,
                    story: story,
                    groupIndex: index,
                    dragOffsetOpacity: dragOffsetOpacity,  // ✅ Pass for UI fading
                    onDismiss: onDismiss
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .offset(y: viewerDragOffset)  // ✅ Apply to entire viewer
        .transition(.move(edge: .bottom))
//        .statusBarHidden()
        .onAppear {
            manager.currentGroupIndex = initialGroupIndex
        }
        
        // ✅ VIEWER-LEVEL GESTURE 1: Drag to dismiss
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    // Only allow downward drag
                    guard value.translation.height > 0 else { return }
                    
                    // Ensure vertical drag (not horizontal swipe)
                    guard abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
                    
                    // Pause stories while dragging
                    manager.isPaused = true
                    viewerDragOffset = value.translation.height
                }
                .onEnded { value in
                    if viewerDragOffset > 150 {
                        // Dismiss entire viewer
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onDismiss()
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewerDragOffset = 0
                        }
                    }
                    
                    // Resume stories
                    manager.isPaused = false
                }
        )
        
        // ✅ VIEWER-LEVEL GESTURE 2: Long press to pause
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
            // On release - do nothing
        } onPressingChanged: { pressing in
            // Set global pause state
            manager.isPaused = pressing
            
            // ✅ CRITICAL FIX for Stuck View:
            // If the gesture was interrupted (user dragged then held), check the offset.
            if !pressing && viewerDragOffset > 0 {
                // If they had already dragged it down a bit (> 50), assume they wanted to dismiss
                if viewerDragOffset > 50 {
                    Logger.debug("👋 Dismissing stuck view (interrupted drag)")
                    withAnimation(.easeInOut(duration: 0.25)) {
                        onDismiss()
                    }
                } else {
                    // If it was just a tiny micro-drag, snap back safely
                    Logger.debug("🧹 Recovering from interrupted drag gesture")
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewerDragOffset = 0
                    }
                }
            }
            
            Logger.debug(pressing ? "⏸️ Stories paused (long press)" : "▶️ Stories resumed")
        }
    }
    
    // ✅ Calculate opacity based on drag offset
    private var dragOffsetOpacity: CGFloat {
        1.0 - min(abs(viewerDragOffset) / 500, 1.0)
    }
}
