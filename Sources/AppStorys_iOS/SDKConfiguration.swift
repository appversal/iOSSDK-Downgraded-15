//
//  SDKConfiguration.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 07/10/25.
//


import Foundation

public struct SDKConfiguration: Sendable {
    let appID: String
    let accountID: String
    let baseURL: String
    
    public init(
        appID: String,
        accountID: String,
        baseURL: String = "https://users.appstorys.com"
    ) {
        self.appID = appID
        self.accountID = accountID
        self.baseURL = baseURL
    }
}
