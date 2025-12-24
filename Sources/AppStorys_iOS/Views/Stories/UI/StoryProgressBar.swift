//
//  StoryProgressBar.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Progress bar updates synchronously with timer (no animation lag)
//

import SwiftUI
import Kingfisher

/// Segmented progress bar showing progress through story slides
struct StoryProgressBar: View {
    let slideCount: Int
    let currentProgress: CGFloat // 0.0 to slideCount (e.g., 1.5 means halfway through slide 2)
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<slideCount, id: \.self) { index in
                ProgressSegment(
                    currentProgress: currentProgress,
                    segmentIndex: index
                )
            }
        }
        .frame(height: 3)
    }
}

/// Individual progress segment - updates instantly without animation
private struct ProgressSegment: View {
    let currentProgress: CGFloat
    let segmentIndex: Int
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let slideProgress = currentProgress - CGFloat(segmentIndex)
            let clampedProgress = min(max(slideProgress, 0), 1)
            
            Capsule()
                .fill(.secondary)
                .overlay(
                    Capsule()
                        .fill(Color.white)
                        .frame(width: width * clampedProgress),
                    alignment: .leading
                )
        }
        // ✅ NO animation - progress updates instantly with timer
        .animation(nil, value: currentProgress)
    }
}

/// Header with thumbnail, name, mute button (for videos), and close button
struct StoryHeader: View {
    let story: StoryDetails
    let showMuteButton: Bool
    let isMuted: Bool
    let onMuteToggle: () -> Void
    let onClose: () -> Void
    let opacity: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            KFImage(URL(string: story.thumbnail))
                .placeholder {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            // Name
            if let name = story.name, !name.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: story.nameColor) ?? .white)
                }
            }
            
            Spacer()
            
            // ✅ Mute button (only shown for video slides)
            if showMuteButton {
                Button(action: onMuteToggle) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
//                        .background(.ultraThinMaterial, in: Circle())
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .symbolRenderingMode(.hierarchical)
                        .symbolReplaceCompat()
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
//                        .background(.ultraThinMaterial, in: Circle())
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .opacity(opacity)
        .animation(.easeInOut(duration: 0.2), value: showMuteButton)
    }
}
