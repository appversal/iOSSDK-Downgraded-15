//
//  CaptureTagBridge.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Separate tagging for widgets vs regular elements
//

import SwiftUI
import UIKit

// MARK: - Public Screen Capture API

extension AppStorys {
    
    /// Create a capture button that handles everything automatically
    /// ✅ NO PARAMETERS: Uses .captureContext() from your views
    /// Usage: sdk.captureButton()
    @MainActor
    public func captureButton() -> some View {
        ScreenCaptureButton {
            // ✅ captureScreen() now gets view from context automatically
            try await self.captureScreen()
        }
    }
}

// MARK: - Public Tagging Extensions

extension View {
    /// Tag a regular UI element for screen capture
    /// These will be sent to /identify-elements/ with screenshot
    ///
    /// Usage:
    /// ```swift
    /// Text("Hello")
    ///     .captureAppStorysTag("hello_text")
    /// ```
    public func captureAppStorysTag(_ identifier: String) -> some View {
        let prefixedId = "APPSTORYS_ELEMENT_\(identifier)"
        return self.background(
            CaptureTagBridge(identifier: prefixedId)
        )
    }
    
    /// Tag a widget for screen capture
    /// These will be sent to /identify-positions/ separately
    ///
    /// Usage:
    /// ```swift
    /// AppStorys.Widgets()
    ///     .captureAppStorysWidgetTag("first_widget")
    /// ```
    public func captureAppStorysWidgetTag(_ identifier: String) -> some View {
        let prefixedId = "APPSTORYS_WIDGET_\(identifier)"
        return self.background(
            CaptureTagBridge(identifier: prefixedId)
        )
    }
}

// MARK: - Internal Bridge

private struct CaptureTagBridge: UIViewRepresentable {
    let identifier: String
    
    func makeUIView(context: Context) -> CaptureTagView {
        let view = CaptureTagView()
        view.accessibilityIdentifier = identifier
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: CaptureTagView, context: Context) {
        uiView.accessibilityIdentifier = identifier
    }
}

private class CaptureTagView: UIView {
    override var accessibilityIdentifier: String? {
        didSet {
            // Just store it - ElementRegistry will find it via hierarchy scan
        }
    }
}
