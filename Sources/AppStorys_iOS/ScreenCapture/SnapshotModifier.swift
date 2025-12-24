//
//  SnapshotModifier.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 05/11/25.
//


import SwiftUI
import UIKit

// MARK: - SwiftUI Snapshot Modifier
extension View {
    public func appstorysSnapshot(trigger: Bool,
                                  onComplete: @escaping (UIImage) -> Void) -> some View {
        modifier(SnapshotModifier(trigger: trigger, onComplete: onComplete))
    }
}

private struct SnapshotModifier: ViewModifier {
    var trigger: Bool
    var onComplete: (UIImage) -> Void

    @State private var snapshotAnchor = UIView(frame: .zero)

    func body(content: Content) -> some View {
        content
            .background(ViewExtractor(view: snapshotAnchor))
            .compositingGroup()
            .onChangeCompat(of: trigger) { _, newValue in
                if newValue {
                    generateSnapshot()
                }
            }
    }

    private func generateSnapshot() {
        // Go two levels up (SwiftUI adds invisible wrapping views)
        guard let target = snapshotAnchor.superview?.superview else {
            print("⚠️ Snapshot anchor not attached properly")
            return
        }

        let renderer = UIGraphicsImageRenderer(size: target.bounds.size)
        let image = renderer.image { _ in
            target.drawHierarchy(in: target.bounds, afterScreenUpdates: true)
        }

        onComplete(image)
    }
}

// MARK: - UIKit ViewExtractor
private struct ViewExtractor: UIViewRepresentable {
    var view: UIView
    func makeUIView(context: Context) -> UIView {
        view.backgroundColor = .clear
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
