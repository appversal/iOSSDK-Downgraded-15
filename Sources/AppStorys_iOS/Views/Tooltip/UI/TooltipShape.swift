//
//  ArrowDirection.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 03/11/25.
//


import SwiftUI

enum ArrowDirection {
    case up, down, left, right
    
    var isVertical: Bool {
        self == .up || self == .down
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct TooltipShape: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let arrowDirection: ArrowDirection
    let arrowWidth: CGFloat
    let arrowHeight: CGFloat
    let arrowOffset: CGFloat
    let color: Color
    
    init(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        arrowDirection: ArrowDirection,
        arrowWidth: CGFloat,
        arrowHeight: CGFloat,
        arrowOffset: CGFloat = 0,
        color: Color = Color(.systemBackground)
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.arrowDirection = arrowDirection
        self.arrowWidth = arrowWidth
        self.arrowHeight = arrowHeight
        self.arrowOffset = arrowOffset
        self.color = color
    }
    
    var body: some View {
        ZStack(alignment: .center) {

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .frame(width: width, height: height)
            
            // Arrow flush against rectangle edge
            arrow
                .offset(arrowPositionOffset)
        }
        .frame(width: totalWidth, height: totalHeight)
    }
    
    private var totalWidth: CGFloat {
        arrowDirection.isVertical ? width : width + arrowHeight
    }
    
    private var totalHeight: CGFloat {
        arrowDirection.isVertical ? height + arrowHeight : height
    }
    
    private var arrowPositionOffset: CGSize {
        switch arrowDirection {
        case .up:
            return CGSize(width: arrowOffset, height: -height / 2 - arrowHeight / 2)
        case .down:
            return CGSize(width: arrowOffset, height: height / 2 + arrowHeight / 2)
        case .left:
            return CGSize(width: -width / 2 - arrowHeight / 2, height: arrowOffset)
        case .right:
            return CGSize(width: width / 2 + arrowHeight / 2, height: arrowOffset)
        }
    }
    
    @ViewBuilder
    private var arrow: some View {
        let isVertical = arrowDirection.isVertical
        let size = isVertical ?
            CGSize(width: arrowWidth, height: arrowHeight) :
            CGSize(width: arrowHeight, height: arrowWidth)
        
        Triangle()
            .fill(color)
            .frame(width: size.width, height: size.height)
            .rotationEffect(arrowRotation)
    }
    
    private var arrowRotation: Angle {
        switch arrowDirection {
        case .up: return .degrees(0)
        case .down: return .degrees(180)
        case .left: return .degrees(-90)
        case .right: return .degrees(90)
        }
    }
}

// MARK: - Preview
struct TooltipShape_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            TooltipShape(
                width: 200,
                height: 100,
                cornerRadius: 12,
                arrowDirection: .up,
                arrowWidth: 20,
                arrowHeight: 10,
                arrowOffset: 0,
                color: .blue
            )
            
            TooltipShape(
                width: 200,
                height: 100,
                cornerRadius: 12,
                arrowDirection: .down,
                arrowWidth: 20,
                arrowHeight: 10,
                arrowOffset: 30,
                color: .green
            )
            
            TooltipShape(
                width: 200,
                height: 100,
                cornerRadius: 12,
                arrowDirection: .left,
                arrowWidth: 20,
                arrowHeight: 10,
                arrowOffset: -20,
                color: .orange
            )
            
            TooltipShape(
                width: 200,
                height: 100,
                cornerRadius: 12,
                arrowDirection: .right,
                arrowWidth: 20,
                arrowHeight: 10,
                arrowOffset: 0,
                color: .purple
            )
        }
        .padding(50)
    }
}
