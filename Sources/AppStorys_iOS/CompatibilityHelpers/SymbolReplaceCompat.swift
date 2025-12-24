//
//  SwiftUIView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 23/12/25.
//

import SwiftUI

extension View {

    @ViewBuilder
    func symbolReplaceCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(
                .symbolEffect(.replace)
            )
        } else if #available(iOS 16.0, *) {
            self.contentTransition(
                .opacity
            )
        } else {
            self.transition(
                .opacity
            )
        }
    }
}

