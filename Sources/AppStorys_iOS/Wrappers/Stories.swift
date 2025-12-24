//
//  Stories.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//


import SwiftUI

public extension AppStorys {
    /// Public-facing Stories view — displays all story campaigns
    struct Stories: View {
        @ObservedObject private var sdk = AppStorys.shared

        private let size: CGFloat
        private let ringWidth: CGFloat
        private let spacing: CGFloat

        public init(size: CGFloat = 70, ringWidth: CGFloat = 3, spacing: CGFloat = 12) {
            self.size = size
            self.ringWidth = ringWidth
            self.spacing = spacing
        }

        public var body: some View {
            StoryGroupThumbnailViewWrapper(
                sdk: sdk,
                size: size,
                ringWidth: ringWidth,
                spacing: spacing
            )
        }
    }
}

/// Internal bridging view (keeps logic isolated)
private struct StoryGroupThumbnailViewWrapper: View {
    @ObservedObject var sdk: AppStorys
    let size: CGFloat
    let ringWidth: CGFloat
    let spacing: CGFloat

    var body: some View {
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
                        sdk.presentStory(campaign: item.campaign, initialGroupIndex: item.originalIndex)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var sortedStoryGroups: [StoryGroupItem] {
        var allStories: [StoryGroupItem] = []

        for campaign in sdk.storyCampaigns {
            for (index, story) in campaign.stories.enumerated() {
                let isViewed = sdk.storyManager.isGroupViewed(story.id)
                allStories.append(
                    StoryGroupItem(
                        campaign: campaign,
                        story: story,
                        originalIndex: index,
                        isViewed: isViewed
                    )
                )
            }
        }

        return allStories.sorted { !$0.isViewed && $1.isViewed }
    }
}

private struct StoryGroupItem: Identifiable {
    let campaign: StoryCampaign
    let story: StoryDetails
    let originalIndex: Int
    let isViewed: Bool
    var id: String { story.id }
}
