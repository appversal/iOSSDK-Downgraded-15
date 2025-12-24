//
//  WebSocketClient.swift
//  AppStorys_iOS
//
//  Fixed: Connection identity and proper lifecycle management
//

import Foundation

/// WebSocket client with connection identity and proper cleanup
actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var messageHandler: (@Sendable (String) -> Void)?
    private var lastProcessedMessageId: String?
    
    // ✅ NEW: Connection identity and state
    private var connectionId: UUID?
    private var isConnected = false
    
    // Message buffer for handling chunked messages
    private var messageBuffer = ""
    
    // ✅ NEW: Track if we're in the middle of connecting
    private var isConnecting = false
    
    /// Connect to WebSocket with config
    func connect(
        config: WebSocketConfig,
        onMessage: @escaping @Sendable (String) -> Void
    ) async throws {
        // ✅ CRITICAL: Disconnect any existing connection first
        if isConnected || isConnecting {
            Logger.info("🔄 Disconnecting existing WebSocket before new connection")
            await disconnect()
            
            // Give old connection time to clean up
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // ✅ Generate new connection ID
        let newConnectionId = UUID()
        connectionId = newConnectionId
        isConnecting = true
        
        Logger.info("🆔 Creating WebSocket connection [\(newConnectionId)]")
        
        self.messageHandler = onMessage
        
        guard let url = URL(string: config.url) else {
            isConnecting = false
            throw AppStorysError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.sessionID, forHTTPHeaderField: "Session-ID")
        request.timeoutInterval = 30
        
        // Create URLSession with proper configuration for WebSocket
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        session = URLSession(configuration: configuration)
        webSocketTask = session?.webSocketTask(with: request)
        
        Logger.info("🌐 Connecting to WebSocket: \(url.absoluteString)")
        
        webSocketTask?.resume()
        
        // Wait a moment for connection to establish
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // ✅ Check if this connection was cancelled during setup
        guard connectionId == newConnectionId else {
            Logger.warning("⚠️ Connection [\(newConnectionId)] was cancelled during setup")
            isConnecting = false
            throw AppStorysError.webSocketError("Connection cancelled")
        }
        
        isConnected = true
        isConnecting = false
        messageBuffer = "" // Reset buffer on new connection
        Logger.info("✅ WebSocket connection [\(newConnectionId)] established")
        
        // Start listening for messages (with connection ID binding)
        Task {
            await receiveMessages(connectionId: newConnectionId)
        }
    }
    
    func isConnectedStatus() -> Bool {
        return isConnected
    }
    
    func disconnect() async {
        // ✅ Clear connection ID first to invalidate any pending operations
        let oldConnectionId = connectionId
        connectionId = nil
        isConnected = false
        isConnecting = false
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        messageHandler = nil
        messageBuffer = "" // Clear buffer on disconnect
        
        if let oldId = oldConnectionId {
            Logger.debug("🔌 WebSocket [\(oldId)] disconnected")
        } else {
            Logger.debug("🔌 WebSocket disconnected (no active connection)")
        }
    }
    
    // ✅ UPDATED: Bind message receiving to specific connection ID
    private func receiveMessages(connectionId: UUID) async {
        // ✅ Check if this is still the active connection
        guard self.connectionId == connectionId else {
            Logger.debug("⏭️ Ignoring messages for old connection [\(connectionId)]")
            return
        }
        
        guard isConnected, let task = webSocketTask else {
            Logger.warning("⚠️ Cannot receive - not connected [\(connectionId)]")
            return
        }
        
        do {
            let message = try await task.receive()
            
            // ✅ Double-check connection ID before processing
            guard self.connectionId == connectionId else {
                Logger.debug("⏭️ Ignoring message for old connection [\(connectionId)]")
                return
            }
            
            switch message {
            case .string(let text):
                await handleMessageChunk(text, connectionId: connectionId)
                
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) {
                    await handleMessageChunk(text, connectionId: connectionId)
                } else {
                    Logger.warning("⚠️ Received non-UTF8 data")
                }
                
            @unknown default:
                Logger.warning("⚠️ Unknown message type received")
                break
            }
            
            // Continue listening if still the active connection
            if self.connectionId == connectionId && isConnected {
                await receiveMessages(connectionId: connectionId)
            }
            
        } catch let error as NSError {
            // Only log if this is still the active connection
            guard self.connectionId == connectionId else {
                return
            }
            
            // Check if it's just a normal closure
            if error.domain == NSPOSIXErrorDomain && error.code == 57 {
                Logger.debug("🔌 WebSocket [\(connectionId)] closed by server")
            } else {
                Logger.error("❌ WebSocket [\(connectionId)] receive error", error: error)
            }
            isConnected = false
            messageBuffer = "" // Clear buffer on error
        }
    }
    
    /// ✅ UPDATED: Handle message chunks with connection ID validation
    private func handleMessageChunk(_ text: String, connectionId: UUID) async {
        // ✅ Validate connection ID
        guard self.connectionId == connectionId else {
            Logger.debug("⏭️ Ignoring chunk for old connection [\(connectionId)]")
            return
        }
        
        // Add to buffer
        messageBuffer += text
        
        // Log chunk for debugging
        logMessageChunk(text, connectionId: connectionId)
        
        // Check if we have a complete JSON message
        if isCompleteJSON(messageBuffer) {
            Logger.debug("📨 Complete message received for [\(connectionId)] (\(messageBuffer.count) chars)")
            
            // Send complete message to handler
            messageHandler?(messageBuffer)
            
            // Reset buffer for next message
            messageBuffer = ""
        } else {
            Logger.debug("⏳ Buffering incomplete JSON for [\(connectionId)] (\(messageBuffer.count) chars so far)")
            // Continue receiving more chunks
        }
    }
    
    /// Log message in chunks for readability
    private func logMessageChunk(_ text: String, connectionId: UUID) {
        let chunkSize = 800
        for i in stride(from: 0, to: text.count, by: chunkSize) {
            let start = text.index(text.startIndex, offsetBy: i)
            let end = text.index(start, offsetBy: min(chunkSize, text.count - i))
            Logger.debug("📨 WS [\(connectionId)] Chunk: \(String(text[start..<end]))")
        }
    }
    
    /// Check if string is valid complete JSON
    private func isCompleteJSON(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        guard let data = string.data(using: .utf8) else { return false }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return true
        } catch {
            // Not valid JSON yet - need more data
            return false
        }
    }
    
    /// Check if message should be processed (prevents duplicates)
    func shouldProcessMessage(messageId: String?) -> Bool {
        guard let messageId = messageId else { return true }
        
        if messageId == lastProcessedMessageId {
            Logger.debug("⏭️ Duplicate message skipped: \(messageId)")
            return false
        }
        
        lastProcessedMessageId = messageId
        return true
    }
}
