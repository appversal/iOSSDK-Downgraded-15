//
//  File.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//

import Foundation
import os.log

struct Logger {
    private static let subsystem = "com.appstorys.sdk"
    private static let logger = os.Logger(subsystem: subsystem, category: "AppStorys")
    
    static func info(_ message: String) {
        #if DEBUG
        logger.info("\(message)")
//        print("ℹ️ [AppStorys] \(message)")
        #endif
    }
    
    static func error(_ message: String, error: Error? = nil) {
        #if DEBUG
        if let error = error {
            logger.error("\(message): \(error.localizedDescription)")
//            print("❌ [AppStorys] \(message): \(error)")
        } else {
            logger.error("\(message)")
//            print("❌ [AppStorys] \(message)")
        }
        #endif
    }
    
    static func debug(_ message: String) {
        #if DEBUG
        logger.debug("\(message)")
//        print("🐛 [AppStorys] \(message)")
        #endif
    }
    
    static func warning(_ message: String) {
        #if DEBUG
        logger.warning("\(message)")
//        print("⚠️ [AppStorys] \(message)")
        #endif
    }
}
