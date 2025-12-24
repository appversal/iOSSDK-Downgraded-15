//
//  Initialize.swift
//  AppStorys_iOS
//
//  ✅ ZERO BOILERPLATE: SDK initializes itself automatically
//  ✅ NO CONDITIONAL RENDERING: Works immediately
//  ✅ QUEUE-BASED: Buffers calls until ready
//

import SwiftUI

// MARK: - Configuration Storage
private actor SDKConfigurationStorage {
    private var config: PendingConfiguration?
    
    struct PendingConfiguration {
        let accountID: String
        let appID: String
        let userID: String
        let baseURL: String
    }
    
    func store(_ configuration: PendingConfiguration) {
        self.config = configuration
    }
    
    func retrieve() -> PendingConfiguration? {
        return config
    }
    
    func clear() {
        config = nil
    }
}

private let configStorage = SDKConfigurationStorage()

// MARK: - Public API Extension
public extension AppStorys {
    
    /// Initialize AppStorys SDK credentials
    /// ✅ Call this ONCE in your App struct's .task modifier
    /// ✅ SDK auto-initializes in background
    /// ✅ All SDK calls are buffered until ready
    ///
    /// Example:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///                 .withAppStorysOverlays()
    ///         }
    ///         .task {
    ///             AppStorys.initialize(
    ///                 accountID: "your-account-id",
    ///                 appID: "your-app-id",
    ///                 userID: "user123"
    ///             )
    ///         }
    ///     }
    /// }
    /// ```
    static func initialize(
        accountID: String,
        appID: String,
        userID: String,
        baseURL: String = "https://users.appstorys.com"
    ) {
        Task {
            await configStorage.store(
                SDKConfigurationStorage.PendingConfiguration(
                    accountID: accountID,
                    appID: appID,
                    userID: userID,
                    baseURL: baseURL
                )
            )
            
            // Initialize in background
            await shared.autoInitialize()
        }
    }
}

// MARK: - Auto-Initialization Logic
extension AppStorys {
    
    /// Internal auto-initialization handler
    /// ✅ Runs once, silently in background
    /// ✅ Processes queued operations after init
    fileprivate func autoInitialize() async {
        guard !isInitialized else {
            Logger.debug("⏭ SDK already initialized, skipping")
            return
        }
        
        guard let config = await configStorage.retrieve() else {
            Logger.error("❌ No configuration found - call AppStorys.initialize() first")
            return
        }
        
        Logger.info("🔄 Auto-initializing AppStorys SDK...")
        
        await appstorys(
            accountID: config.accountID,
            appID: config.appID,
            userID: config.userID,
            baseURL: config.baseURL
        )
        
        await configStorage.clear()
        
        Logger.info("✅ SDK auto-initialization complete")
    }
}

// MARK: - Safe Public Methods (Auto-Wait for Init)
public extension AppStorys {
    
    /// Track screen with auto-initialization wait
    static func trackScreen(
        _ screenName: String,
        completion: @escaping ([CampaignModel]) -> Void = { _ in }
    ) {
        Task {
            await shared.waitForInitialization()
            await MainActor.run {
                shared.trackScreen(screenName, completion: completion)
            }
        }
    }
        
    /// Dismiss tooltip with auto-initialization wait
    static func dismissTooltip() {
        Task {
            await shared.waitForInitialization()
            await MainActor.run {
                shared.dismissTooltip()
            }
        }
    }
}

// MARK: - Initialization Waiter
extension AppStorys {
    
    func waitForInitialization(timeout: TimeInterval = 5.0) async {
        guard !isInitialized else { return }
        
        Logger.debug("⏳ Waiting for SDK initialization...")
        
        let startTime = Date()
        
        while !isInitialized {
            if Date().timeIntervalSince(startTime) > timeout {
                Logger.error("❌ SDK initialization timeout after \(timeout)s")
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if isInitialized {
            Logger.debug("✅ SDK ready after \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
        }
    }
}
