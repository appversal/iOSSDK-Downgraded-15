//
//  MilestoneGaugeStyle.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/12/25.
//

import SwiftUI

struct MilestoneGaugeStyle: GaugeStyle {
    var milestones: [MilestoneProgressBar.MilestonePoint]
    var activeColor: Color
    var stripeColor: Color
    var barHeight: CGFloat    // <-- NEW VARIABLE
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            let progressWidth = geo.size.width * configuration.value
            let maxValue = milestones.last?.value ?? 1
            
            ZStack(alignment: .leading) {
                
                // Track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: barHeight)
                
                // Fill
                Capsule()
                    .fill(activeColor)
                    .frame(width: progressWidth, height: barHeight)
                
                // Stripes
                StripedPattern(color: stripeColor)
                    .frame(width: progressWidth, height: barHeight)
                    .clipShape(Capsule())
                
                // Milestone icons
                ForEach(milestones.indices, id: \.self) { i in
                    let m = milestones[i]
                    let percent = CGFloat(m.value / maxValue)
                    let xPos = geo.size.width * percent
                    
                    Group {
                        if let imgString = m.imageUrl, let url = URL(string: imgString) {
                            AppStorysImageView(url: url, contentMode: .fill, showShimmer: false)
                                .frame(width: barHeight*1.2, height: barHeight*1.2)   // scaled with bar height
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        } else {
                            Image(systemName: "smallcircle.filled.circle.fill")
                                .foregroundColor(.white)
                                .frame(width: barHeight, height: barHeight)
                                .background(Circle().fill(m.color))
                        }
                    }
                    .position(x: xPos, y: geo.size.height / 2)
                }
            }
        }
    }
}
