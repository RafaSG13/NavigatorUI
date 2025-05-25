//
//  RouterLogger.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import Foundation

enum LogLevel: String {
    case debug = "🟢 DEBUG"
    case info = "🔵 INFO"
    case warning = "🟠 WARNING"
    case error = "🔴 ERROR"
}

enum EventMessage: String {
    case push = "Push"
    case pop = "Pop"
    case presentSheet = "PresentSheet"
    case dismissSheet = "DismissSheet"
    case presentFullScreen = "PresentFullScreen"
    case dismissFullScreen = "DismissFullScreen"
    case deepLink = "DeepLink"
    case invalidUrl = "InvalidURl"
    case activate = "Activate"
    case deactivate = "Deactivate"
}

struct RouterLogger {
    public var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    private var routerID: String

    init(routerID: String) {
        self.routerID = routerID
    }

    func log(_ eventMessage: EventMessage, isActive: Bool) {
        guard isEnabled else { return }
        print("[Router \(routerID)] \(isActive ? "🟢" : "🔴") \(eventMessage)")
    }

    func log(_ eventMessage: EventMessage) {
        guard isEnabled else { return }
        print("[Router \(routerID)] \(eventMessage)")
    }
}
