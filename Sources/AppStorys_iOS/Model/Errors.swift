//
//  AppStorysError.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation

public enum AppStorysError: Error, LocalizedError {
    case notInitialized
    case authenticationFailed
    case noAccessToken
    case networkError(Error)
    case invalidResponse
    case invalidURL
    case webSocketError(String)
    case decodingError(Error)
    case serverError(Int)
    case timeout
    case taskGroupFailure(String)  // ✅ More descriptive than "unexpectedError"
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "SDK not initialized. Call appstorys() first."
        case .authenticationFailed:
            return "Authentication failed. Check your credentials."
        case .noAccessToken:
            return "No access token found."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidURL:
            return "Invalid URL"
        case .webSocketError(let message):
            return "WebSocket error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .timeout:
            return "Request timeout"
        case .taskGroupFailure(let reason):
            return "Task group failure: \(reason)"
        }
    }
}


public enum ScreenCaptureError: Error, LocalizedError {
    case featureDisabled
    case managerNotInitialized
    case noActiveScreen
    case screenshotFailed
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case rateLimitExceeded
    case noActiveScreenContext
    case screenMismatch

    public var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "Screen capture is disabled. Enable it in your dashboard."
        case .managerNotInitialized:
            return "Screen capture manager not initialized"
        case .noActiveScreen:
            return "No active screen to capture. Call trackScreen() first."
        case .screenshotFailed:
            return "Failed to capture screenshot"
        case .invalidURL:
            return "Invalid upload URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .rateLimitExceeded:
            return "Please wait 5 seconds between captures"
        case .noActiveScreenContext:
            return "No valid capture context found. Ensure .trackAppStorysScreen() is applied."
        case .screenMismatch:
            return "The active view does not match the tracked screen. Ensure .trackAppStorysScreen() is used on the current screen."

        }
    }
}
