//
//  MilestoneProgressBar.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/12/25.
//

import SwiftUI

struct MilestoneProgressBar: View {
    @ObservedObject var viewModel: MilestoneViewModel
    let styling: MilestoneStyling?
    let headerImage: String?
    
    struct MilestonePoint {
        let value: Double
        let imageUrl: String?
        let color: Color
    }
    
    var progress: Double {
        let values = viewModel.milestoneValues
        guard !values.isEmpty, let maxValue = values.last else { return 0 }
        
        if viewModel.currentStep == 0 { return 0 }
        if viewModel.currentStep >= values.count { return 1.0 }
        
        let completedIndex = viewModel.currentStep - 1
        if completedIndex >= 0 && completedIndex < values.count {
            return values[completedIndex] / maxValue
        }
        
        return 0
    }
    
    var body: some View {
        let values = viewModel.milestoneValues
        let items = viewModel.sortedMilestoneItems
        
        // Get dynamic height from styling (fallback to 20)
        let barHeight: CGFloat = CGFloat(styling?.progressBarHeight.doubleValue ?? 20)
        
        // Generate UI points
        let uiMilestones: [MilestonePoint] = zip(values.indices, values).map { i, v in
            let colors: [Color] = [.blue, .orange, .purple, .pink]
            let imageUrl = items.indices.contains(i) ? items[i].pbImage : nil
            
            return MilestonePoint(
                value: v,
                imageUrl: imageUrl,
                color: colors[i % colors.count]
            )
        }
        
        HStack(alignment: .top, spacing: 12) {
            
            if let headerImg = headerImage, let url = URL(string: headerImg) {
                AppStorysImageView(url: url, contentMode: .fit, showShimmer: true)
                    .frame(width: barHeight*1.8, height: barHeight*1.8)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                
                let label: String = {
                    if viewModel.currentStep == 0 {
                        return viewModel.stepLabels.first ?? "Start"
                    } else if viewModel.currentStep >= viewModel.stepLabels.count {
                        return "Completed"
                    } else {
                        return viewModel.stepLabels[viewModel.currentStep - 1]
                    }
                }()
                
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: styling?.labelColor ?? "#000000"))
                
                if #available(iOS 16.0, *) {
                    Gauge(value: progress, in: 0...1) { }
                        .gaugeStyle(MilestoneGaugeStyle(
                            milestones: uiMilestones,
                            activeColor: Color(hex: styling?.activeColor ?? "#34C759"),
                            stripeColor: Color(hex: styling?.stripeColor ?? "#FFFFFF33"),
                            barHeight: barHeight
                        ))
                        .frame(height: barHeight)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                } else {
                    // iOS 15 fallback (custom progress bar)
                    LegacyMilestoneProgressBar(
                        progress: progress,
                        milestones: uiMilestones,
                        activeColor: Color(hex: styling?.activeColor ?? "#34C759"),
                        stripeColor: Color(hex: styling?.stripeColor ?? "#FFFFFF33"),
                        barHeight: barHeight
                    )
                }

                StepLabelsBar(
                    values: values,
                    maxValue: values.last ?? 1,
                    textColor: Color(hex: styling?.counterTextColor ?? "#8E8E93")
                )
                .frame(height: 20)
            }
            .padding(.trailing)
        }
    }
}
