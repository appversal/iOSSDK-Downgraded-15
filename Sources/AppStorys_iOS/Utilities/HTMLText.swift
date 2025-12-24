//
//  HTMLText.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 21/11/25.
//


import SwiftUI

public struct HTMLText: View {
    private let html: String

    public init(_ html: String) {
        self.html = html
    }

    public var body: some View {
        if let attributed = html.toAttributedString {
            Text(attributed)
                .font(.headline)
        } else {
            Text("Unable to load content")
                .foregroundColor(.secondary)
        }
    }
}

public extension String {
    var toAttributedString: AttributedString? {
        guard let data = self.data(using: .utf8) else { return nil }

        do {
            // 1️⃣ Convert HTML → NSAttributedString (UIKit)
            let nsAttr = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )

            // 2️⃣ Convert NSAttributedString → SwiftUI AttributedString
            return AttributedString(nsAttr)

        } catch {
            print("HTML parsing error:", error.localizedDescription)
            return nil
        }
    }
}
