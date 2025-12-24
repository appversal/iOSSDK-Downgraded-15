//
//  SwiftUIView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 23/12/25.
//

import SwiftUI

// MARK: - Safe Area Padding Compat
extension View {
    @ViewBuilder
    func safeAreaPaddingCompat(_ edges: Edge.Set = .all) -> some View {
        if #available(iOS 17.0, *) {
            self.safeAreaPadding(edges)
        } else {
            self.padding(edges)
        }
    }
}
