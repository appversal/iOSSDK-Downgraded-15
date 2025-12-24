//
//  AuthManager.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation

/// Handles authentication with /validate-account endpoint
actor AuthManager {
    private let config: SDKConfiguration
    private let keychain = KeychainHelper()
    
    private var accessToken: String?
    private var refreshToken: String?
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1.0, 2.0, 4.0] // Exponential backoff
    
    init(config: SDKConfiguration) {
        self.config = config
    }
    
    /// Authenticate with backend and store tokens (with retry logic)
    func authenticate() async throws {
        Logger.info("🔑 Authenticating with AppStorys...")
        
        var lastError: Error?
        
        for (attempt, delay) in retryDelays.enumerated() {
            do {
                try await performAuthentication()
                return // Success!
                
            } catch let error as NSError where isRetryableError(error) {
                lastError = error
                
                if attempt < retryDelays.count - 1 {
                    Logger.warning("⚠️ Auth attempt \(attempt + 1) failed, retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    Logger.error("❌ Auth failed after \(maxRetries) attempts")
                }
            } catch {
                // Non-retryable error (e.g., 401, invalid credentials)
                throw error
            }
        }
        
        throw lastError ?? AppStorysError.authenticationFailed
    }
    
    /// Perform the actual authentication request
    private func performAuthentication() async throws {
        // ✅ Use config.baseURL instead of hardcoded URL
        guard let url = URL(string: "\(config.baseURL)/validate-account") else {
            throw AppStorysError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15 // Add timeout
        
        let body: [String: String] = [
            "account_id": config.accountID,
            "app_id": config.appID
        ]
        
        let jsonData = try JSONEncoder().encode(body)
        request.httpBody = jsonData
        
        // Debug logging
        Logger.debug("📤 POST \(url.absoluteString)")
        Logger.debug("📦 Body: \(String(data: jsonData, encoding: .utf8) ?? "invalid")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppStorysError.invalidResponse
        }
        
        // Debug response
        Logger.debug("📥 Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            Logger.debug("📥 Response Body: \(responseString)")
        }
        
        // Handle different status codes
        switch httpResponse.statusCode {
        case 200:
            // Success - decode and store tokens
            let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
            
            // Store tokens in Keychain
            try await keychain.save(key: "access_token", value: tokenResponse.accessToken)
            try await keychain.save(key: "refresh_token", value: tokenResponse.refreshToken)
            
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            
            Logger.info("✅ Authentication successful")
            
        case 401, 403:
            // Invalid credentials - don't retry
            Logger.error("❌ Authentication failed: Invalid credentials")
            throw AppStorysError.authenticationFailed
            
        case 500...599:
            // Server error - retryable
            Logger.warning("⚠️ Server error: \(httpResponse.statusCode)")
            throw AppStorysError.serverError(httpResponse.statusCode)
            
        default:
            Logger.error("❌ Unexpected status code: \(httpResponse.statusCode)")
            throw AppStorysError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Check if error is retryable
    private func isRetryableError(_ error: NSError) -> Bool {
        // Network errors that should be retried
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorTimedOut:
                return true
            default:
                return false
            }
        }
        
        // Server errors (5xx) are retryable
        if let appError = error as? AppStorysError,
           case .serverError(let code) = appError,
           (500...599).contains(code) {
            return true
        }
        
        return false
    }
    
    func getAccessToken() async throws -> String {
        if let token = accessToken {
            return token
        }
        
        // Try loading from Keychain
        if let storedToken = try await keychain.get(key: "access_token") {
            self.accessToken = storedToken
            return storedToken
        }
        
        throw AppStorysError.noAccessToken
    }
    
    func clearTokens() async throws {
        try await keychain.delete(key: "access_token")
        try await keychain.delete(key: "refresh_token")
        accessToken = nil
        refreshToken = nil
        Logger.debug("🗑️ Tokens cleared from Keychain")
    }
}
