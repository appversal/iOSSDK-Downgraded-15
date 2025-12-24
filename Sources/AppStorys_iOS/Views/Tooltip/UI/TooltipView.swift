//
//  TooltipView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//

import SwiftUI

/// Interactive tooltip overlay with smart positioning
struct TooltipView: View {
    @EnvironmentObject var sdk: AppStorys
    @ObservedObject var manager: TooltipManager
    
    // Debug flag - set to true to see visual debugging
    private let showDebugOverlay = false

    var body: some View {
        GeometryReader { geo in
            if let (campaign, step, targetFrame) = manager.getCurrentTooltip(),
               targetFrame.width > 0 && targetFrame.height > 0 {
                
                let highlightPadding = CGFloat(Double(step.styling.highlightPadding) ?? 8)
                let highlightRadius  = CGFloat(Double(step.styling.highlightRadius) ?? 12)
                
                ZStack {
                    // Background tap area
                    Rectangle()
                        .fill(.gray.opacity(0.6))
                        .contentShape(Rectangle()) // ensures full-tap region
                        .onTapGesture {
                            // Allow background tap to go next
                            manager.nextStep()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    
                    // Spotlight overlay
                    SpotlightOverlay(
                        targetFrame: targetFrame,
                        padding: highlightPadding,
                        cornerRadius: highlightRadius,
                        overlayOpacity: 0.75
                    )
                    .allowsHitTesting(false) // make sure spotlight doesn’t block taps
                    
                    // Tooltip content (unchanged)
                    tooltipContent(
                        campaign: campaign,
                        step: step,
                        targetFrame: targetFrame,
                        screenSize: geo.size
                    )
                }

                .compositingGroup()
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private func tooltipContent(
        campaign: CampaignModel,
        step: TooltipStep,
        targetFrame: CGRect,
        screenSize: CGSize
    ) -> some View {
        let position = calculatePosition(targetFrame: targetFrame, step: step, screenSize: screenSize)
        let arrow = calculateArrowDirection(targetFrame: targetFrame, tooltipPosition: position)
        let offset = calculateArrowOffset(targetFrame: targetFrame, tooltipPosition: position, arrowDirection: arrow)
        
        // Log debug info
        let _ = logDebugInfo(step: step, targetFrame: targetFrame, position: position, arrow: arrow, offset: offset, screenSize: screenSize)
        
        Group {
            // Tooltip bubble with arrow
            TooltipBubble(
                step: step,
                position: position,
                arrowDirection: arrow,
                arrowOffset: offset,
                onTap: { handleTooltipTap(campaign: campaign, step: step) }
            )
            
            // Close button (top-right corner)
            if step.styling.closeButton {
                CloseButton(action: { manager.dismiss() })
            }
            
            // Step navigation (bottom center)
            if manager.totalSteps > 1 {
                StepNavigation(
                    currentStep: manager.currentStep,
                    totalSteps: manager.totalSteps,
                    isFirst: manager.isFirstStep,
                    isLast: manager.isLastStep,
                    onPrevious: { manager.previousStep() },
                    onNext: { manager.nextStep() }
                )
            }
            
            // Debug overlay
//            if showDebugOverlay {
//                DebugOverlay(
//                    targetFrame: targetFrame,
//                    tooltipPosition: position,
//                    tooltipSize: CGSize(width: step.tooltipWidth, height: step.tooltipHeight),
//                    arrowDirection: arrow,
//                    arrowHeight: step.arrowHeight,
//                    arrowOffset: offset
//                )
//            }
        }
    }
    
    // MARK: - Position Calculation
    
    private func calculatePosition(
        targetFrame: CGRect,
        step: TooltipStep,
        screenSize: CGSize
    ) -> CGPoint {
        let spacing: CGFloat = 16
        let safeMargin: CGFloat = 20
        
        // Calculate available space on all sides
        let spaceTop = targetFrame.minY - safeMargin
        let spaceBottom = screenSize.height - targetFrame.maxY - safeMargin
        let spaceLeft = targetFrame.minX - safeMargin
        let spaceRight = screenSize.width - targetFrame.maxX - safeMargin
        
        // Required space for tooltip
        let requiredWidth = step.tooltipWidth + step.arrowHeight + spacing
        let requiredHeight = step.tooltipHeight + step.arrowHeight + spacing
        
        // Find best side
        var candidates: [(side: Side, space: CGFloat)] = []
        if spaceLeft >= requiredWidth { candidates.append((.left, spaceLeft)) }
        if spaceRight >= requiredWidth { candidates.append((.right, spaceRight)) }
        if spaceTop >= requiredHeight { candidates.append((.top, spaceTop)) }
        if spaceBottom >= requiredHeight { candidates.append((.bottom, spaceBottom)) }
        
        // Choose side with most space, or fallback to any side
        let bestSide = candidates.max(by: { $0.space < $1.space })?.side
            ?? [Side.bottom, .top, .left, .right].max(by: {
                space(for: $0, target: targetFrame, screen: screenSize) < space(for: $1, target: targetFrame, screen: screenSize)
            })!
        
        return position(for: bestSide, targetFrame: targetFrame, step: step, screenSize: screenSize, spacing: spacing, safeMargin: safeMargin)
    }
    
    private func position(
        for side: Side,
        targetFrame: CGRect,
        step: TooltipStep,
        screenSize: CGSize,
        spacing: CGFloat,
        safeMargin: CGFloat
    ) -> CGPoint {
        let halfWidth = step.tooltipWidth / 2
        let halfHeight = step.tooltipHeight / 2
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        switch side {
        case .top:
            y = targetFrame.minY - halfHeight - step.arrowHeight - spacing
            x = clamp(targetFrame.midX, min: halfWidth + safeMargin, max: screenSize.width - halfWidth - safeMargin)
            
        case .bottom:
            y = targetFrame.maxY + halfHeight + step.arrowHeight + spacing
            x = clamp(targetFrame.midX, min: halfWidth + safeMargin, max: screenSize.width - halfWidth - safeMargin)
            
        case .left:
            x = targetFrame.minX - halfWidth - step.arrowHeight - spacing
            y = clamp(targetFrame.midY, min: halfHeight + safeMargin, max: screenSize.height - halfHeight - safeMargin)
            
        case .right:
            x = targetFrame.maxX + halfWidth + step.arrowHeight + spacing
            y = clamp(targetFrame.midY, min: halfHeight + safeMargin, max: screenSize.height - halfHeight - safeMargin)
        }
        
        return CGPoint(x: x, y: y)
    }
    
    private func space(for side: Side, target: CGRect, screen: CGSize) -> CGFloat {
        switch side {
        case .top: return target.minY
        case .bottom: return screen.height - target.maxY
        case .left: return target.minX
        case .right: return screen.width - target.maxX
        }
    }
    
    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
    
    // MARK: - Arrow Calculation
    
    private func calculateArrowDirection(
        targetFrame: CGRect,
        tooltipPosition: CGPoint
    ) -> ArrowDirection {
        let verticalDistance = abs(tooltipPosition.y - targetFrame.midY)
        let horizontalDistance = abs(tooltipPosition.x - targetFrame.midX)
        
        if verticalDistance > horizontalDistance {
            return tooltipPosition.y < targetFrame.midY ? .down : .up
        } else {
            return tooltipPosition.x < targetFrame.midX ? .right : .left
        }
    }
    
    private func calculateArrowOffset(
        targetFrame: CGRect,
        tooltipPosition: CGPoint,
        arrowDirection: ArrowDirection
    ) -> CGFloat {
        switch arrowDirection {
        case .up, .down:
            let nearestX = clamp(tooltipPosition.x, min: targetFrame.minX, max: targetFrame.maxX)
            return nearestX - tooltipPosition.x
            
        case .left, .right:
            let nearestY = clamp(tooltipPosition.y, min: targetFrame.minY, max: targetFrame.maxY)
            return nearestY - tooltipPosition.y
        }
    }
    
    // MARK: - Actions
    
    private func handleTooltipTap(campaign: CampaignModel, step: TooltipStep) {
        switch step.clickAction {
        case "nextStep":
            manager.nextStep()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
        case "openLink":
            if let urlString = step.link, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
        case "triggerEvent":
            if let eventName = step.eventName {
                sdk.addTrackedEvent(eventName)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
        case "deepLink":
            if let urlString = step.deepLinkUrl, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Debug Logging
    
    private func logDebugInfo(
        step: TooltipStep,
        targetFrame: CGRect,
        position: CGPoint,
        arrow: ArrowDirection,
        offset: CGFloat,
        screenSize: CGSize
    ) {
        Logger.debug("🎯 Tooltip: target=\(targetFrame), position=\(position), arrow=\(arrow), offset=\(String(format: "%.1f", offset))")
    }
    
    // MARK: - Supporting Types
    
    private enum Side {
        case top, bottom, left, right
    }
}

// MARK: - Tooltip Bubble

struct TooltipBubble: View {
    let step: TooltipStep
    let position: CGPoint
    let arrowDirection: ArrowDirection
    let arrowOffset: CGFloat
    let onTap: () -> Void
    
    var body: some View {
            // Shape with arrow
            TooltipShape(
                width: step.tooltipWidth,
                height: step.tooltipHeight,
                cornerRadius: step.tooltipCornerRadius,
                arrowDirection: arrowDirection,
                arrowWidth: step.arrowWidth,
                arrowHeight: step.arrowHeight,
                arrowOffset: arrowOffset
            )
            .overlay {
                contentView
                    .frame(width: step.tooltipWidth, height: step.tooltipHeight)
            }
        
        .position(position)
        .onTapGesture(perform: onTap)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch step.type {
        case "image":
            AppStorysImageView(
                url: step.url.flatMap { URL(string: $0) },
                contentMode: .fill,
                showShimmer: true,
                cornerRadius: 0
            )
            .clipShape(
                RoundedRectangle(cornerRadius: step.tooltipCornerRadius, style: .continuous)
            )
            .padding(contentPadding)
            
        case "text":
            Text(step.url ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(contentPadding)
            
        default:
            EmptyView()
        }
    }
    
    private var contentPadding: EdgeInsets {
        EdgeInsets(
            top: CGFloat(Double(step.styling.spacing.paddingTop) ?? 12),
            leading: CGFloat(Double(step.styling.spacing.paddingLeft) ?? 16),
            bottom: CGFloat(Double(step.styling.spacing.paddingBottom) ?? 12),
            trailing: CGFloat(Double(step.styling.spacing.paddingRight) ?? 16)
        )
    }
}

// MARK: - Close Button

struct CloseButton: View {
    let action: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                        .background(Circle().fill(Color.black.opacity(0.3)))
                }
                .padding()
            }
            Spacer()
        }
    }
}

// MARK: - Step Navigation

struct StepNavigation: View {
    let currentStep: Int
    let totalSteps: Int
    let isFirst: Bool
    let isLast: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                if !isFirst {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                
                Text("\(currentStep + 1) / \(totalSteps)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.5)))
                
                Button(action: onNext) {
                    Image(systemName: isLast ? "checkmark.circle.fill" : "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 40)
        }
    }
}
