//
//  SwiftUIView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 23/12/25.
//

import SwiftUI

// MARK: - Scroll Bounce Intent (iOS-agnostic)
enum ScrollBounceIntent {
    case automatic   // equivalent to .basedOnSize
    case always
    case never
}

// MARK: - Scroll Bounce Compat
extension View {

    @ViewBuilder
    func scrollBounceCompat(_ intent: ScrollBounceIntent) -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceModern(intent)
        } else {
            self
        }
    }

    // MARK: - iOS 16.4+
    @available(iOS 16.4, *)
    @ViewBuilder
    private func scrollBounceModern(
        _ intent: ScrollBounceIntent
    ) -> some View {
        switch intent {
        case .automatic:
            self.scrollBounceBehavior(.basedOnSize)

        case .always:
            self.scrollBounceBehavior(.always)

        case .never:
            self
        }
    }
}
