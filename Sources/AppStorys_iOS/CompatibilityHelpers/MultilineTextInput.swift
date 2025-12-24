//
//  SwiftUIView.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 23/12/25.
//

import SwiftUI

// MARK: - Multiline Text Input Compat
struct MultilineTextInput: View {
    let placeholder: String
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        if #available(iOS 16.0, *) {
            TextField(placeholder, text: $text, axis: .vertical)
                .focused($isFocused)
        } else {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 6)
                }

                TextEditor(text: $text)
                    .focused($isFocused)
            }
        }
    }
}

// MARK: - Line Limit Range Compat
extension View {
    @ViewBuilder
    func lineLimitCompat(_ range: ClosedRange<Int>) -> some View {
        if #available(iOS 16.0, *) {
            self.lineLimit(range)
        } else {
            self
        }
    }
}
