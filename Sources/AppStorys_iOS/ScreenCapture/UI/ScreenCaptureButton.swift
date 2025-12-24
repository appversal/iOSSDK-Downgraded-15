//
//  ScreenCaptureButton.swift
//  AppStorys_iOS
//
//  Enhanced with confetti celebration on successful capture
//

import SwiftUI
import ConfettiSwiftUI

public struct ScreenCaptureButton: View {
    let onCapture: () async throws -> Void
    
    @State private var isCapturing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var confettiTrigger = 0
    
    // Positioning
    private let position: Position
    
    public enum Position {
        case bottomCenter
        case bottomTrailing
        case bottomLeading
        
        var alignment: Alignment {
            switch self {
            case .bottomCenter: return .bottom
            case .bottomTrailing: return .bottomTrailing
            case .bottomLeading: return .bottomLeading
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .bottomCenter:
                return EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0)
            case .bottomTrailing:
                return EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 20)
            case .bottomLeading:
                return EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 0)
            }
        }
    }
    
    public init(
        position: Position = .bottomCenter,
        onCapture: @escaping () async throws -> Void
    ) {
        self.position = position
        self.onCapture = onCapture
    }
    
    public var body: some View {
        Button(action: {
            Task { await capture() }
        }) {
            HStack(spacing: 8) {
                icon
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(buttonColor)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            )
        }
        .disabled(isCapturing)
        .opacity(isCapturing ? 0.6 : 1.0)
        .confettiCannon(
            counter: $confettiTrigger
        )
        .alert("Capture Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
            Button("Retry") {
                errorMessage = nil
                Task { await capture() }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    @ViewBuilder
    private var icon: some View {
        if isCapturing {
            ProgressView()
                .progressViewStyle(
                    CircularProgressViewStyle(tint: .white)
                )
                .scaleEffect(0.8)

        } else if showSuccess {

            if #available(iOS 17.0, *) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: showSuccess)

            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .scaleEffect(showSuccess ? 1.1 : 1.0)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.6),
                        value: showSuccess
                    )
            }

        } else {
            Image(systemName: "camera.fill")
                .foregroundStyle(.white)
        }
    }

    private var buttonTitle: String {
        if isCapturing { return "Capturing..." }
        if showSuccess { return "Captured!" }
        return "Capture Screen"
    }
    
    private var buttonColor: Color {
        if showSuccess { return .green }
        return .blue
    }
    
    private func capture() async {
        isCapturing = true
        errorMessage = nil

        do {
            // ✅ Validate screen tracking first
            let sdk = AppStorys.shared
            
            guard let currentScreen = sdk.currentScreen else {
                throw ScreenCaptureError.noActiveScreen
            }
            
            guard sdk.captureContextProvider.currentView != nil else {
                throw ScreenCaptureError.noActiveScreenContext
            }
            if !sdk.isScreenCurrentlyVisible(currentScreen) {
                throw ScreenCaptureError.screenMismatch
            }
            Logger.info("📸 Triggering capture for tracked screen: \(currentScreen)")
            
            // ✅ Proceed with actual capture
            try await onCapture()

            await MainActor.run {
                showSuccess = true
                confettiTrigger += 1
                Logger.info("🎉 Screen capture successful - confetti triggered!")
            }

            try await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                showSuccess = false
            }

        } catch let error as ScreenCaptureError {
            await MainActor.run {
                switch error {
                case .noActiveScreen:
                    errorMessage = "No tracked screen found. Please ensure this view uses .trackAppStorysScreen()"
                case .noActiveScreenContext:
                    errorMessage = "No capture context available. Make sure .trackAppStorysScreen() is applied correctly."
                default:
                    errorMessage = error.localizedDescription
                }
                Logger.error("❌ Capture aborted - \(errorMessage ?? "Unknown reason")")
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                Logger.error("❌ Capture failed", error: error)
            }

        }

        await MainActor.run {
            isCapturing = false
        }
    }

}
