//
//  AppStorysWidgetImageView.swift
//  AppStorys_iOS
//
//  ✅ STANDARD: Fills the container based on parent dimensions
//

import SwiftUI
import Kingfisher

struct AppStorysWidgetImageView: View {
    let url: URL?
    let showShimmer: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if let url = url {
                KFImage(url)
                    .placeholder { placeholderView }
                    .cacheOriginalImage()
                    .resizable()
                    .aspectRatio(contentMode: .fill) // ✅ Fills the fixed frame
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                errorView
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        if showShimmer {
            ShimmerView()
        } else {
            Color.gray.opacity(0.2)
                .overlay(Image(systemName: "photo").foregroundColor(.gray.opacity(0.5)))
        }
    }
    
    private var errorView: some View {
        Color.gray.opacity(0.1)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.gray.opacity(0.6))
                    Text("Failed").font(.caption).foregroundColor(.gray.opacity(0.6))
                }
            )
    }
}
