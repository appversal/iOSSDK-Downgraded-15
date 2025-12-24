//
//  LegacyMilestoneProgressBar.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 23/12/25.
//
import SwiftUI

struct LegacyMilestoneProgressBar: View {

    let progress: Double                 // 0...1
    let milestones: [MilestoneProgressBar.MilestonePoint]
    let activeColor: Color
    let stripeColor: Color
    let barHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let progressWidth = geo.size.width * progress
            let maxValue = milestones.last?.value ?? 1

            ZStack(alignment: .leading) {

                // MARK: - Track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: barHeight)

                // MARK: - Fill
                Capsule()
                    .fill(activeColor)
                    .frame(width: progressWidth, height: barHeight)

                // MARK: - Stripes
                StripedPattern(color: stripeColor)
                    .frame(width: progressWidth, height: barHeight)
                    .clipShape(Capsule())

                // MARK: - Milestones
                ForEach(milestones.indices, id: \.self) { index in
                    let milestone = milestones[index]
                    let percent = CGFloat(milestone.value / maxValue)
                    let xPos = geo.size.width * percent

                    milestoneView(milestone)
                        .position(x: xPos, y: geo.size.height / 2)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: progress)
        }
        .frame(height: barHeight)
    }

    @ViewBuilder
    private func milestoneView(_ milestone: MilestoneProgressBar.MilestonePoint) -> some View {
        if let imageUrl = milestone.imageUrl,
           let url = URL(string: imageUrl) {

            AppStorysImageView(
                url: url,
                contentMode: .fill,
                showShimmer: false
            )
            .frame(width: barHeight * 1.2, height: barHeight * 1.2)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
            )

        } else {
            Image(systemName: "smallcircle.filled.circle.fill")
                .foregroundColor(.white)
                .frame(width: barHeight, height: barHeight)
                .background(
                    Circle().fill(milestone.color)
                )
        }
    }
}
