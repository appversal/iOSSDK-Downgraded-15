//
//  StripedPattern.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 08/12/25.
//

import SwiftUI

struct StripedPattern: View {
    var color: Color
    @State private var startTime = Date()
    
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let elapsed = timeline.date.timeIntervalSince(startTime)
                let animationOffset = CGFloat(elapsed * 30).truncatingRemainder(dividingBy: 40)
                
                Canvas { context, size in
                    let stripeWidth: CGFloat = 10
                    let stripeSpacing: CGFloat = 10
                    let totalWidth = stripeWidth + stripeSpacing
                    let startX = -totalWidth + animationOffset
                    
                    var x = startX
                    while x < size.width + totalWidth {
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                            p.addLine(to: CGPoint(x: x + stripeWidth - size.height * 0.5, y: size.height))
                            p.addLine(to: CGPoint(x: x - size.height * 0.5, y: size.height))
                            p.closeSubpath()
                        }
                        context.fill(path, with: .color(color))
                        x += totalWidth
                    }
                }
            }
        }
        .clipShape(Capsule())
    }
}
