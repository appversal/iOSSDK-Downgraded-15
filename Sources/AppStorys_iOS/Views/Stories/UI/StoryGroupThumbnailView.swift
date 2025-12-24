//
//  StoryGroupThumbnailView.swift
//  AppStorys_iOS
//
//  Fixed: Proper viewed state colors + handle empty names
//

import SwiftUI
import Kingfisher

/// Horizontal scrollable view showing story group thumbnails
/// Stories are sorted: unviewed first, viewed last
struct StoryGroupThumbnailView: View {
    @ObservedObject var manager: StoryManager
    let campaigns: [StoryCampaign]
    let onTap: (StoryCampaign, Int) -> Void
    
    // Styling configuration
    let size: CGFloat
    let ringWidth: CGFloat
    let spacing: CGFloat
    
    public init(
        manager: StoryManager,
        campaigns: [StoryCampaign],
        size: CGFloat = 70,
        ringWidth: CGFloat = 3,
        spacing: CGFloat = 12,
        onTap: @escaping (StoryCampaign, Int) -> Void
    ) {
        self.manager = manager
        self.campaigns = campaigns
        self.size = size
        self.ringWidth = ringWidth
        self.spacing = spacing
        self.onTap = onTap
    }

    private var sortedStoryGroups: [StoryGroupItem] {
        var allStories: [StoryGroupItem] = []
        
        // Flatten all campaigns and stories
        for campaign in campaigns {
            for (index, story) in campaign.stories.enumerated() {
                let isViewed = manager.isGroupViewed(story.id)
                allStories.append(StoryGroupItem(
                    campaign: campaign,
                    story: story,
                    originalIndex: index,
                    isViewed: isViewed
                ))
            }
        }
        
        // ✅ STABLE SORT: Use story.order as tie-breaker
        return allStories.sorted { lhs, rhs in
            // Primary: unviewed first
            if lhs.isViewed != rhs.isViewed {
                return !lhs.isViewed
            }
            // ✅ Secondary: use server's order field for stability
            return lhs.story.order < rhs.story.order
        }
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(sortedStoryGroups) { item in
                    StoryThumbnail(
                        story: item.story,
                        isViewed: item.isViewed,
                        size: size,
                        ringWidth: ringWidth
                    )
                    .onTapGesture {
                        // ✅ CRITICAL: Use original index from campaign, not sorted index
                        onTap(item.campaign, item.originalIndex)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Story Group Item (Internal Model)

/// Wrapper that preserves original campaign and index for correct tap handling
private struct StoryGroupItem: Identifiable {
    let campaign: StoryCampaign
    let story: StoryDetails
    let originalIndex: Int  // ✅ Original position in campaign.stories array
    let isViewed: Bool
    
    var id: String { story.id }
}

/// Individual story thumbnail with ring indicator
struct StoryThumbnail: View {
    let story: StoryDetails
    let isViewed: Bool
    let size: CGFloat
    let ringWidth: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack{
                KFImage(URL(string: story.thumbnail))
                    .placeholder {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                
                if isViewed {
                    Circle()
                        .fill(.quaternary)
                        .frame(width: size, height: size)
                }
            }
            .padding(ringWidth)
            .background(
                colorScheme == .dark ? Color.black : Color.white,
                in: Circle()
            )
            .padding(ringWidth)
            .background(
                Circle()
                    .strokeBorder(
                        isViewed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(ringGradient),
                        lineWidth: ringWidth
                    )
            )
            
            if let name = story.name, !name.isEmpty {
                Text(name)
                    .font(.footnote)
                    .foregroundColor(nameColor)
                    .lineLimit(2)
                    .frame(width: size + ringWidth * 4)
            }
            
            Spacer()
        }
    }
    
    // âœ… Computed property for name color
    private var nameColor: Color {
        if isViewed {
            return .secondary
        } else {
            return Color(hex: story.nameColor) ?? .primary
        }
    }
    
    // âœ… Computed property for ring gradient (unviewed state)
    private var ringGradient: LinearGradient {
        let ringColor = Color(hex: story.ringColor) ?? .blue
        
        return LinearGradient(
            colors: [ringColor, ringColor.opacity(0.7), ringColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
