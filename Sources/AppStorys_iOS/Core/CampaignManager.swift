//
//  CampaignManager.swift
//  AppStorys_iOS
//
//  Fixed: Returns tuple with screenCaptureEnabled
//

import Foundation

actor CampaignManager {
    private let networkClient: NetworkClient
    private let webSocketClient: WebSocketClient
    private let authManager: AuthManager
    private let baseURL: String
    
    private var pendingContinuations: [UUID: SafeContinuationWrapper<[CampaignModel]>] = [:]
    private var currentScreenCaptureEnabled = false
    
    // ✅ NEW: Track last trackScreen call to prevent spam
    private var lastTrackScreenTime: Date?
    private let trackScreenDebounceInterval: TimeInterval = 0.5 // 500ms
    
    init(
        networkClient: NetworkClient,
        webSocketClient: WebSocketClient,
        authManager: AuthManager,
        baseURL: String
    ) {
        self.networkClient = networkClient
        self.webSocketClient = webSocketClient
        self.authManager = authManager
        self.baseURL = baseURL
    }
    
    // ✅ FIXED: Now returns tuple with screenCaptureEnabled
    func trackScreen(
        screenName: String,
        userID: String,
        attributes: [String: AnyCodable],
        timeout: TimeInterval = 10.0
    ) async throws -> (campaigns: [CampaignModel], screenCaptureEnabled: Bool) {
        // ✅ Rate limit check
        if let lastCall = lastTrackScreenTime,
           Date().timeIntervalSince(lastCall) < trackScreenDebounceInterval {
            Logger.warning("⚠️ trackScreen() called too quickly - debouncing")
            try await Task.sleep(nanoseconds: UInt64(trackScreenDebounceInterval * 1_000_000_000))
        }
        
        lastTrackScreenTime = Date()
        
        Logger.info("📺 Tracking screen: \(screenName)")
        
        // ✅ CRITICAL: Disconnect existing WebSocket FIRST
        await webSocketClient.disconnect()
        
        // Small delay to ensure cleanup completes
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let wsResponse = try await fetchWebSocketConfig(
            screenName: screenName,
            userID: userID,
            attributes: attributes
        )
        
        currentScreenCaptureEnabled = wsResponse.screenCaptureEnabled ?? false
        
        let campaigns = try await connectAndReceiveCampaigns(
            config: wsResponse.ws,
            screenName: screenName,
            timeout: timeout
        )
        
        // ✅ Return tuple with both campaigns and capture state
        return (campaigns: campaigns, screenCaptureEnabled: currentScreenCaptureEnabled)
    }
    
    private func fetchWebSocketConfig(
        screenName: String,
        userID: String,
        attributes: [String: AnyCodable]
    ) async throws -> WebSocketConnectionResponse {
        let url = URL(string: "\(baseURL)/track-user")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let accessToken = try await authManager.getAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "user_id": userID,
            "screenName": screenName,
            "attributes": attributes.mapValues { $0.value }
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AppStorysError.invalidResponse
        }
        
        let wsResponse = try JSONDecoder().decode(WebSocketConnectionResponse.self, from: data)
        Logger.info("✅ WebSocket config received (expires in \(wsResponse.ws.expires)s)")
        
        return wsResponse
    }
    
    private func connectAndReceiveCampaigns(
        config: WebSocketConfig,
        screenName: String,
        timeout: TimeInterval
    ) async throws -> [CampaignModel] {
        let requestID = UUID()
        
        return try await withThrowingTaskGroup(of: TaskResult.self) { group in
            
            // Task 1: WebSocket message handler
            group.addTask {
                let result = await withCheckedContinuation { (continuation: CheckedContinuation<[CampaignModel], Never>) in
                    let wrapper = SafeContinuationWrapper(
                        continuation: continuation,
                        id: requestID
                    )
                    
                    Task {
                        await self.storeContinuation(wrapper, for: requestID)
                        
                        do {
                            try await self.webSocketClient.connect(config: config) { [weak self] message in
                                guard let self = self else { return }
                                
                                Task {
                                    await self.handleWebSocketMessage(
                                        message,
                                        screenName: screenName,
                                        requestID: requestID
                                    )
                                }
                            }
                            
                        } catch {
                            await self.resumeContinuation(requestID, with: .failure(error))
                        }
                    }
                }
                
                return .campaigns(result)
            }
            
            // Task 2: Timeout handler
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self.resumeContinuation(requestID, with: .timeout)
                return .timeout
            }
            
            defer {
                group.cancelAll()
                
                Task {
                    await self.forceResumeContinuation(requestID, reason: "defer cleanup")
                    await self.webSocketClient.disconnect()
                }
            }
            
            guard let firstResult = try await group.next() else {
                throw AppStorysError.taskGroupFailure("No tasks completed")
            }
            
            switch firstResult {
            case .campaigns(let campaigns):
                Logger.info("✅ Received \(campaigns.count) campaigns")
                return campaigns
                
            case .timeout:
                Logger.warning("⏱️ WebSocket timeout after \(timeout)s - no campaigns")
                return []
            }
        }
    }
    
    private func handleWebSocketMessage(
        _ message: String,
        screenName: String,
        requestID: UUID
    ) async {
        do {
            Logger.debug("📨 Received WebSocket message (\(message.count) chars)")
            
            // -------------------------------
            // 1️⃣ Offload JSON decode to background thread
            // -------------------------------
            let campaignResponse = try await Task.detached(priority: .high) {
                return try JSONDecoder().decode(
                    CampaignResponse.self,
                    from: Data(message.utf8)
                )
            }.value
            
            let campaigns = campaignResponse.campaigns ?? []
            
            // -------------------------------
            // 2️⃣ Heavy filtering on background thread
            // -------------------------------
            let filteredCampaigns = await Task.detached(priority: .high) {
                campaigns.filter { campaign in
                    guard let campaignScreen = campaign.screen else { return false }
                    
                    return campaignScreen
                        .lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    ==
                    screenName
                        .lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }.value
            
            Logger.info("✅ Parsed \(filteredCampaigns.count) campaigns for \(screenName)")
            
            // -------------------------------
            // 3️⃣ Return results
            // (Only this part executes on the actor)
            // -------------------------------
            await resumeContinuation(requestID, with: .success(filteredCampaigns))
            
        } catch {
            Logger.error("❌ Failed to parse campaign response", error: error)
            await resumeContinuation(requestID, with: .failure(error))
        }
    }

    
    // MARK: - Continuation Lifecycle Management
    
    private func storeContinuation(_ wrapper: SafeContinuationWrapper<[CampaignModel]>, for id: UUID) {
        pendingContinuations[id] = wrapper
        Logger.debug("📝 Stored continuation [\(id)]")
    }
    
    private func resumeContinuation(_ id: UUID, with result: ContinuationResult) async {
        guard let wrapper = pendingContinuations.removeValue(forKey: id) else {
            Logger.debug("⚠️ Continuation [\(id)] already resumed")
            return
        }
        
        switch result {
        case .success(let campaigns):
            wrapper.resume(returning: campaigns)
            Logger.debug("✅ Continuation [\(id)] resumed with \(campaigns.count) campaigns")
            
        case .failure(let error):
            Logger.warning("⚠️ Continuation [\(id)] resumed with error: \(error.localizedDescription)")
            wrapper.resume(returning: [])
            
        case .timeout:
            wrapper.resume(returning: [])
            Logger.debug("⏱️ Continuation [\(id)] resumed due to timeout")
        }
    }
    
    private func forceResumeContinuation(_ id: UUID, reason: String) async {
        guard let wrapper = pendingContinuations.removeValue(forKey: id) else {
            return
        }
        
        Logger.warning("🧹 Force resuming continuation [\(id)] - reason: \(reason)")
        wrapper.resume(returning: [])
    }
    
    // MARK: - Helper Types
    
    private enum TaskResult {
        case campaigns([CampaignModel])
        case timeout
    }
    
    private enum ContinuationResult {
        case success([CampaignModel])
        case failure(Error)
        case timeout
    }
    
    // MARK: - Event Tracking
    
    func trackEvent(
        campaignID: String,
        userID: String,
        event: String,
        metadata: [String: AnyCodable]? = nil
    ) async throws {
        let eventBaseURL = baseURL.replacingOccurrences(of: "users", with: "tracking")
        let url = URL(string: "\(eventBaseURL)/capture-event")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let accessToken = try await authManager.getAccessToken()
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "campaign_id": campaignID,
            "user_id": userID,
            "event": event
        ]
        
        if let metadata = metadata {
            body["metadata"] = metadata.mapValues { $0.value }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              [200, 201, 202, 204].contains(httpResponse.statusCode) else {
            throw AppStorysError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        Logger.info("✅ Event tracked: \(event)")
    }
}

// MARK: - SafeContinuationWrapper

final class SafeContinuationWrapper<T: Sendable>: @unchecked Sendable {
    private let continuation: CheckedContinuation<T, Never>
    private let id: UUID
    private var isResumed = false
    private let lock = NSLock()
    
    init(continuation: CheckedContinuation<T, Never>, id: UUID) {
        self.continuation = continuation
        self.id = id
    }
    
    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isResumed else {
            Logger.warning("⚠️ Attempted to resume continuation [\(id)] multiple times!")
            return
        }
        
        isResumed = true
        continuation.resume(returning: value)
    }
}
