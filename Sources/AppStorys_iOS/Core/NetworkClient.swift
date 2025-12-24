//
//  File.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation

/// Generic HTTP client for API requests
actor NetworkClient {
    private let authManager: AuthManager
    private let session: URLSession
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        
        // Configure URLSession with reasonable timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // 30 seconds for request
        config.timeoutIntervalForResource = 60  // 60 seconds total
        self.session = URLSession(configuration: config)
    }
    
    /// Make authenticated POST request
    func post<T: Decodable>(
        url: URL,
        body: Encodable,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth header
        let token = try await authManager.getAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Encode body
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(body)
        request.httpBody = jsonData
        
        Logger.debug("📤 POST \(url.path)")
        Logger.debug("🔑 Auth: Bearer \(token.prefix(20))...")
        if let bodyString = String(data: jsonData, encoding: .utf8) {
            Logger.debug("📦 Request Body:\n\(bodyString)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppStorysError.invalidResponse
        }
        
        Logger.debug("📥 Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            Logger.debug("📥 Response Body: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AppStorysError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Make authenticated POST request without response body
    func post(url: URL, body: Encodable) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let token = try await authManager.getAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(body)
        request.httpBody = jsonData
        
        Logger.debug("📤 POST \(url.path)")
        if let bodyString = String(data: jsonData, encoding: .utf8) {
            Logger.debug("📦 Request Body: \(bodyString)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppStorysError.invalidResponse
        }
        
        Logger.debug("📥 Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            Logger.debug("📥 Response Body: \(responseString)")
        }
        
        guard (200...204).contains(httpResponse.statusCode) else {
            throw AppStorysError.serverError(httpResponse.statusCode)
        }
    }
}
