import NavigatorUI
import SwiftUI

/// Collects navigation events so the home screen can show them.
@MainActor
final class EventLog: ObservableObject {
    @Published private(set) var lines: [String] = []

    func record(_ event: NavigationEvent) {
        let line: String
        switch event {
        case .stackChanged(let routes): line = "stack: \(routes.map(\.description).joined(separator: " > "))"
        case .presented(let route): line = "presented \(route)"
        case .dismissed(let route): line = "dismissed \(route.map(\.description) ?? "-")"
        case .popBlocked: line = "pop blocked by guard"
        case .deepLink(let url, let handled): line = "\(handled ? "open" : "unhandled") \(url.absoluteString)"
        case .failure(let message): line = "FAILURE \(message)"
        }
        lines = Array((lines + [line]).suffix(6))
    }
}

@main
struct ExampleApp: App {
    @StateObject private var navigator = Navigator()
    @StateObject private var log = EventLog()

    var body: some Scene {
        WindowGroup {
            NavigationRoot(
                navigator: navigator,
                registry: AppNavigation.registry,
                deepLinks: AppNavigation.deepLinks,
                root: AppRoute.home
            )
            // UIKit hosting does not inherit environment objects from above, so inject them here.
            .decorateScreens { $0.environmentObject(log) }
            .onAppear { navigator.eventHandler = { log.record($0) } }
        }
    }
}
