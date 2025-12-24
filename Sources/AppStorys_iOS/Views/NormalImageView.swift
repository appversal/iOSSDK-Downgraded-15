//
//  AppStorysImageView 2.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 13/11/25.
//


import SwiftUI
import Kingfisher

struct NormalImageView: View {

    // MARK: - Configuration
    let url: URL?
    let contentMode: SwiftUI.ContentMode
    let showShimmer: Bool
    let cornerRadius: CGFloat
    let onSuccess: (() -> Void)?
    let onFailure: ((Error) -> Void)?
    
    // MARK: - State
    @State private var isLoading = true
    @State private var loadFailed = false
    
    // MARK: - Init
    init(
        url: URL?,
        contentMode: SwiftUI.ContentMode = .fit,
        showShimmer: Bool = true,
        cornerRadius: CGFloat = 0,
        onSuccess: (() -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self.url = url
        self.contentMode = contentMode
        self.showShimmer = showShimmer
        self.cornerRadius = cornerRadius
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if let url = url {
                KFImage(url)
                    .placeholder { placeholderView }
                    .onSuccess { _ in
                        isLoading = false
                        loadFailed = false
                        onSuccess?()
                    }
                    .onFailure { error in
                        isLoading = false
                        loadFailed = true
                        onFailure?(error)
                    }
                    // ✅ ADD THIS
                    .cacheOriginalImage()
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .cornerRadius(cornerRadius)
                    .clipped()
            } else {
                errorView
            }
        }
    }

    
    // MARK: - Placeholder View
    @ViewBuilder
    private var placeholderView: some View {
        if showShimmer {
            ShimmerView()
                .cornerRadius(cornerRadius)
        } else {
            Color.gray.opacity(0.2)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.title)
                )
                .cornerRadius(cornerRadius)
        }
    }
    
    // MARK: - Error View
    private var errorView: some View {
        Color.gray.opacity(0.1)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("Failed to load")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            )
            .cornerRadius(cornerRadius)
    }
}
