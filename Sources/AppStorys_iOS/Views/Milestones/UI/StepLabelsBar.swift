//
//  StepLabelsBar.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/12/25.
//

import SwiftUI

struct StepLabelsBar: View {
    let values: [Double]
    let maxValue: Double
    let textColor: Color
    
    var body: some View {
        GeometryReader { geo in
            if maxValue > 0 {
                ZStack(alignment: .topLeading) {
                    ForEach(values.indices, id: \.self) { i in
                        let value = values[i]
                        let percent = CGFloat(value / maxValue)
                        let xPos = (geo.size.width * percent)
                        
                        Text("₹\(Int(value))")
                            .font(.caption2)
                            .foregroundColor(textColor)
                            .position(x: xPos, y: 10)
                            .fixedSize()
                    }
                }
            }
        }
    }
}
