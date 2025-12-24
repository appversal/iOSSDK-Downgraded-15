//
//  SwiftUIView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 23/12/25.
//

import SwiftUI

// MARK: - Font Weight Compat (iOS 13+)
extension View {
    @ViewBuilder
    func fontWeightCompat(_ weight: Font.Weight?) -> some View {
        if #available(iOS 16.0, *) {
            self.fontWeight(weight)
        } else {
            if let weight {
                self.font(
                    Font.system(size: UIFont.labelFontSize).weight(weight)
                )
            } else {
                self
            }
        }
    }
}

private func uiFontWeight(from weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .ultraLight: return .ultraLight
    case .thin: return .thin
    case .light: return .light
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    case .black: return .black
    default: return .regular
    }
}

// MARK: - Italic Compat
extension View {
    @ViewBuilder
    func italicCompat(_ isItalic: Bool = true) -> some View {
        if isItalic {
            if #available(iOS 16.0, *) {
                self.italic()
            } else {
                self.font(.system(size: UIFont.labelFontSize, design: .default).italic())
            }
        } else {
            self
        }
    }
}

// MARK: - Underline Compat (iOS 13+)
extension View {

    @ViewBuilder
    func underlineCompat(
        _ isActive: Bool = true,
        color: Color? = nil
    ) -> some View {
        if #available(iOS 16.0, *) {
            self.underline(isActive, color: color)
        } else {
            if isActive {
                self.overlay(
                    GeometryReader { geometry in
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(color ?? .primary)
                            .offset(y: geometry.size.height - 1)
                    }
                )
            } else {
                self
            }
        }
    }
}
