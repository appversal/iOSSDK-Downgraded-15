//
//  ScreenCaptureManager.swift
//  AppStorys_iOS
//
//  ✅ FIXED: Parallel API uploads with correct element/widget separation
//  ✅ Screenshot & regular elements → /identify-elements/
//  ✅ Widget IDs only → /widget-positions/
//

import UIKit

/// Handles screen capture and upload with widget tracking
actor ScreenCaptureManager {
    private let authManager: AuthManager
    private let baseURL: String
    private let elementRegistry: ElementRegistry
    private var lastCaptureTime: Date?
    
    // Rate limiting: 5 seconds between captures
    private let minimumCaptureInterval: TimeInterval = 5.0
    
    // Render waiting configuration
    private let maxRenderRetries = 10
    private let renderDelayMs: UInt64 = 50
    
    init(
        authManager: AuthManager,
        baseURL: String,
        elementRegistry: ElementRegistry
    ) {
        self.authManager = authManager
        self.baseURL = baseURL
        self.elementRegistry = elementRegistry
    }
    
    /// Capture screen and upload to backend with widget information
    func captureAndUpload(
        screenName: String,
        userId: String,
        rootView: UIView
    ) async throws {
        // 🕐 Step 0: Rate limit check
        if let lastCapture = lastCaptureTime,
           Date().timeIntervalSince(lastCapture) < minimumCaptureInterval {
            Logger.warning("⏳ Rate limited: Please wait \(Int(minimumCaptureInterval))s between captures")
            throw ScreenCaptureError.rateLimitExceeded
        }
        
        lastCaptureTime = Date()
        Logger.info("📸 Starting screen capture for: \(screenName)")
        
        // 🪄 Step 1: Ensure view has rendered before capturing
        await MainActor.run {
            waitForRenderCompletion(of: rootView)
        }
        
        // 🖼️ Step 2: Capture screenshot
        let screenshot = try await MainActor.run {
            try captureScreenshot(from: rootView)
        }
        
        guard let imageData = screenshot.jpegData(compressionQuality: 0.8) else {
            Logger.error("❌ Failed to compress screenshot to JPEG")
            throw ScreenCaptureError.screenshotFailed
        }
        Logger.debug("✅ Screenshot: \(imageData.count / 1024)KB")
        
        // 🧱 Step 3: Extract layout + widgets (SEPARATED)
        let (layoutInfo, widgetIds) = await MainActor.run {
            _ = elementRegistry.discoverElements(in: rootView, forceRefresh: false)
            let layout = elementRegistry.extractLayoutData() // ✅ Only regular elements
            let widgets = elementRegistry.extractWidgetIds() // ✅ Only widget IDs
            return (layout, widgets)
        }
        
        if layoutInfo.isEmpty {
            Logger.info("ℹ️ No tagged elements found (this is optional)")
        } else {
            Logger.debug("✅ Layout: \(layoutInfo.count) regular elements")
        }
        
        if widgetIds.isEmpty {
            Logger.info("ℹ️ No widgets found on this screen")
        } else {
            Logger.info("🎨 Found \(widgetIds.count) widgets: \(widgetIds.joined(separator: ", "))")
        }
        
        // 🚀 Step 4: Upload both APIs in parallel
        async let captureTask = uploadCapture(
            screenName: screenName,
            userId: userId,
            imageData: imageData,
            layoutInfo: layoutInfo
        )
        
        async let widgetTask: Void = {
            guard !widgetIds.isEmpty else {
                Logger.debug("🧩 Skipping widget upload — none found")
                return
            }
            try await uploadWidgetIds(
                screenName: screenName,
                userId: userId,
                widgetIds: widgetIds
            )
        }()
        
        do {
            _ = try await (captureTask, widgetTask)
            Logger.info("✅ Both uploads completed successfully for screen: \(screenName)")
        } catch {
            Logger.error("❌ One or more uploads failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    /// Wait for view hierarchy to finish rendering
    @MainActor
    private func waitForRenderCompletion(of view: UIView) {
        var retries = 0
        while retries < maxRenderRetries {
            if view.layer.needsLayout() {
                Logger.debug("⏳ Waiting for render (\(retries + 1)/\(maxRenderRetries))...")
                view.layoutIfNeeded()
                Thread.sleep(forTimeInterval: Double(renderDelayMs) / 1000.0)
                retries += 1
            } else {
                Logger.debug("✅ Render complete after \(retries) retries")
                return
            }
        }
        Logger.warning("⚠️ Max render retries reached, proceeding anyway")
    }
    
    @MainActor
    private func captureScreenshot(from view: UIView) throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { context in
            let success = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            if !success {
                Logger.warning("⚠️ drawHierarchy returned false - screenshot may be incomplete")
            }
        }
        
        guard image.size.width > 0 && image.size.height > 0 else {
            Logger.error("❌ Captured image has zero size")
            throw ScreenCaptureError.screenshotFailed
        }
        return image
    }
    
    // MARK: - Upload APIs
    
    /// Uploads screenshot + regular elements (no widgets)
    private func uploadCapture(
        screenName: String,
        userId: String,
        imageData: Data,
        layoutInfo: [LayoutElement]
    ) async throws {
        let endpoint = "\(baseURL.replacingOccurrences(of: "users", with: "backend"))/api/v2/appinfo/identify-elements/"
        
        guard let url = URL(string: endpoint) else {
            Logger.error("❌ Invalid URL: \(endpoint)")
            throw ScreenCaptureError.invalidURL
        }
        
        let accessToken = try await authManager.getAccessToken()
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        var body = Data()
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomFileName = "screenshot_\(screenName)_\(timestamp).jpg"
        
        let sizeKB = Double(imageData.count) / 1024.0
        Logger.info("🖼️ Screenshot ready: \(randomFileName) (\(String(format: "%.1f", sizeKB)) KB)")
        
        // Screen name
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"screenName\"\r\n\r\n")
        body.append("\(screenName)\r\n")
        
        // User ID
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n")
        body.append("\(userId)\r\n")
        
        // Layout info (regular elements only)
        let layoutJson = try JSONEncoder().encode(layoutInfo)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"children\"\r\n")
        body.append("Content-Type: application/json\r\n\r\n")
        body.append(layoutJson)
        body.append("\r\n")
        
        // Screenshot
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"screenshot\"; filename=\"\(randomFileName)\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        
        request.httpBody = body
        
        Logger.debug("📤 Uploading capture (screenshot + \(layoutInfo.count) elements) → \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            Logger.error("❌ Capture upload failed")
            throw ScreenCaptureError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        Logger.info("✅ Capture upload complete for \(screenName)")
        if let responseBody = String(data: data, encoding: .utf8) {
            Logger.debug("📥 Response: \(responseBody)")
        }
    }
    
    /// Uploads widget IDs only (no screenshot)
    private func uploadWidgetIds(
        screenName: String,
        userId: String,
        widgetIds: [String]
    ) async throws {
        let endpoint = "\(baseURL.replacingOccurrences(of: "users", with: "backend"))/api/v2/appinfo/identify-positions/"
        
        guard let url = URL(string: endpoint) else {
            Logger.error("❌ Invalid URL for widget upload: \(endpoint)")
            throw ScreenCaptureError.invalidURL
        }
        
        let accessToken = try await authManager.getAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        // ✅ Widget IDs already have "widget_" prefix from ElementRegistry
        // No need to add it again here
        
        let payload: [String: Any] = [
            "screen_name": screenName,
            "position_list": widgetIds
        ]
        
        // Log outgoing payload for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            Logger.debug("🧾 Widget Upload Payload:\n\(jsonString)")
            request.httpBody = jsonData
        }
        
        Logger.debug("📤 Uploading widget IDs (\(widgetIds.count)) → \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("❌ Invalid HTTP response for widget upload")
            throw ScreenCaptureError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorMsg = String(data: data, encoding: .utf8) {
                Logger.error("❌ Widget upload failed [\(httpResponse.statusCode)]: \(errorMsg)")
            }
            throw ScreenCaptureError.serverError(httpResponse.statusCode)
        }
        
        Logger.info("✅ Widget IDs uploaded successfully for \(screenName)")
        if let responseBody = String(data: data, encoding: .utf8) {
            Logger.debug("📥 Widget Response: \(responseBody)")
        }
    }
    @MainActor
    func uploadSwiftUISnapshot(
        _ image: UIImage,
        screenName: String,
        userId: String
    ) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            Logger.error("❌ Failed to convert SwiftUI snapshot to JPEG")
            throw ScreenCaptureError.screenshotFailed
        }

        // ✅ Step 1: Refresh elements before upload
        if let rootView = await AppStorys.shared.captureContextProvider.currentView {
            Logger.debug("🔍 Discovering elements before SwiftUI snapshot upload...")
            await elementRegistry.discoverElements(in: rootView, forceRefresh: true)
        } else {
            Logger.warning("⚠️ No capture context view available — skipping element discovery")
        }

        // ✅ Step 2: Extract layout + widget data
        let layoutInfo: [LayoutElement] = await elementRegistry.extractLayoutData()
        let widgetIds: [String] = await elementRegistry.extractWidgetIds()

        if layoutInfo.isEmpty {
            Logger.info("ℹ️ No tagged elements found when uploading SwiftUI snapshot (optional)")
        } else {
            Logger.debug("✅ Layout: \(layoutInfo.count) regular elements")
        }

        if widgetIds.isEmpty {
            Logger.info("ℹ️ No widgets found when uploading SwiftUI snapshot")
        } else {
            Logger.info("🎨 Found \(widgetIds.count) widgets: \(widgetIds.joined(separator: ", "))")
        }

        // ✅ Step 3: Upload both in parallel
        Logger.debug("📤 Uploading pre-captured SwiftUI snapshot for \(screenName)")

        async let captureUpload: Void = {
            do {
                try await uploadCapture(
                    screenName: screenName,
                    userId: userId,
                    imageData: imageData,
                    layoutInfo: layoutInfo
                )
            } catch {
                Logger.error("❌ Failed to upload SwiftUI snapshot capture: \(error.localizedDescription)")
                throw error
            }
        }()

        async let widgetUpload: Void = {
            guard !widgetIds.isEmpty else { return }
            do {
                try await uploadWidgetIds(
                    screenName: screenName,
                    userId: userId,
                    widgetIds: widgetIds
                )
            } catch {
                Logger.error("⚠️ Widget upload failed: \(error.localizedDescription)")
            }
        }()

        do {
            _ = try await (captureUpload, widgetUpload)
            Logger.info("✅ SwiftUI snapshot upload complete for \(screenName)")
        } catch {
            Logger.error("❌ SwiftUI snapshot upload failed: \(error)")
            throw error
        }
    }
}

// MARK: - Models

public struct LayoutElement: Codable, Sendable {
    let id: String
    let frame: LayoutFrame
    let type: String?
    let depth: Int?
}

struct LayoutFrame: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

// MARK: - Helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
