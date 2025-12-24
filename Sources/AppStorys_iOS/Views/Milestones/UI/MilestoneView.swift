//
//  MilestoneView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/12/25.
//

import SwiftUI

// MARK: - Main View
public struct MilestoneView: View {
    let campaignId: String
    let details: MilestoneDetails
    @StateObject private var viewModel: MilestoneViewModel
    @State private var isVisible = true
    
    public init(campaignId: String, details: MilestoneDetails) {
        self.campaignId = campaignId
        self.details = details
        _viewModel = StateObject(wrappedValue: MilestoneViewModel(details: details))
    }
    
    public var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Group {
                    if let title = details.content?.title, !title.isEmpty {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Color(hex: details.styling?.titleColor ?? "#000000"))
                    }
                }
                // Render specific stylea
                if details.displayType == "progressBar" {
                    MilestoneProgressBar(
                        viewModel: viewModel,
                        styling: details.styling,
                        headerImage: details.headerImage
                    )
                } else {
                    Text("Unsupported display type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            .background(Color(hex: details.styling?.containerBackgroundColor ?? "#FFFFFF"))
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(details.styling?.containerCornerRadius ?? 20), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(details.styling?.containerCornerRadius ?? 20), style: .continuous)
                    .stroke(
                        Color(hex: details.styling?.containerBorderColor ?? "#00000000"),
                        lineWidth: CGFloat(details.styling?.containerBorderWidth ?? 0)
                    )
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                trackViewed()
            }
        }
    }
    
    private func trackViewed() {
        Task {
            await AppStorys.shared.trackEvents(
                eventType: "viewed",
                campaignId: campaignId
            )
        }
    }
}
