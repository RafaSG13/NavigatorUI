//
//  Router.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 24/5/25.
//

import SwiftUI

/// A navigation manager for SwiftUI views that handles push navigation, sheets,
/// and full screen covers. Designed for composable and nested navigation using `NavigationController`.
///
/// `Router` tracks navigation state and coordinates activation and deactivation
/// between parent and child routers, ensuring only one router is active at a time.
///
/// - Parameters:
///   - P: Type conforming to `PushDestination` representing push destinations.
///   - S: Type conforming to `SheetDestination` representing sheet destinations.
///   - F: Type conforming to `FullScreenCoverDestination` representing full screen cover destinations.
public final class Router<P: PushDestination,
                          S: SheetDestination,
                          F: FullScreenCoverDestination>: ObservableObject {

    /// The current navigation stack for push navigation.
    @Published public var navigationPath = NavigationPath()

    /// The currently presented sheet destination.
    @Published public var currentSheet: S?

    /// The currently presented full screen cover destination.
    @Published public var currentFullScreenCover: F?

    /// Unique identifier for debugging and logging.
    let id: UUID

    /// Weak reference to the parent router. Used for coordinating activation/deactivation.
    weak var parentRouter: Router?

    /// Strong reference to the currently active child router.
    var childRouter: Router?

    /// Indicates whether this router is currently active and allowed to perform navigation actions.
    var isActive: Bool = false

    /// Logger used for debugging navigation actions.
    let logger: RouterLogger

    /// Initializes a new `Router` instance with an optional parent.
    ///
    /// - Parameter parent: The parent router in a nested navigation hierarchy.
    public init(parent: Router? = nil) {
        self.id = UUID()
        self.parentRouter = parent
        self.logger = RouterLogger(routerID: id.uuidString)
    }

    /// Performs a push navigation to the given destination.
    ///
    /// - Parameter destination: A value conforming to `PushDestination`.
    ///
    /// - Note: The navigation will only proceed if this router is active.
    public func push(_ destination: P) {
        logger.log(.push, isActive: isActive)
        guard isActive else { return }
        navigationPath.append(destination)
    }

    /// Presents a sheet with the given destination.
    ///
    /// - Parameter destination: A value conforming to `SheetDestination`.
    ///
    /// - Note: The presentation will only proceed if this router is active.
    public func presentSheet(_ destination: S) {
        logger.log(.presentSheet, isActive: isActive)
        guard isActive else { return }
        currentSheet = destination
    }

    /// Presents a full screen cover with the given destination.
    ///
    /// - Parameter destination: A value conforming to `FullScreenCoverDestination`.
    ///
    /// - Note: The presentation will only proceed if this router is active.
    public func presentFullScreenCover(_ destination: F) {
        logger.log(.presentFullScreen, isActive: isActive)
        guard isActive else { return }
        currentFullScreenCover = destination
    }

    /// Handles an incoming deep link URL and performs the corresponding navigation.
    ///
    /// This method attempts to decode the provided `URL` into a valid `Destination`
    /// using the specified `DeepLinkDecoder`. If the router is currently active and the URL
    /// can be decoded successfully, it triggers the appropriate navigation action:
    /// pushing a new view, presenting a sheet, or presenting a full screen cover.
    ///
    /// - Parameters:
    ///   - url: The deep link `URL` to handle.
    ///   - decoder: A `DeepLinkDecoder` responsible for parsing the URL into a `Destination`.
    ///
    /// - Note: Navigation actions will only be performed if the router is active.
    /// - SeeAlso: `DeepLinkDecoder`, `Destination`, `Router`
    public func didReceiveDeepLink(url: URL, decoder: DeepLinkDecoder<P, S, F>) {
        logger.log(.deepLink, isActive: isActive)
        guard isActive else { return }
        guard let destination = decoder.decode(url: url) else {
            logger.log(.invalidUrl, isActive: isActive)
            return
        }

        switch destination {
        case .push(let dest): push(dest)
        case .sheet(let dest): presentSheet(dest)
        case .fullScreenCover(let dest): presentFullScreenCover(dest)
        }
    }

    /// Dismisses the currently presented full screen cover, if this router is nested.
    ///
    /// This is called from within the full screen content, and instructs the parent to dismiss the cover.
    public func dismissFullScreenCover() {
        logger.log(.dismissFullScreen, isActive: isActive)
        self.parentRouter?.currentFullScreenCover = nil
        self.deactivate()
    }

    /// Activates this router, deactivating the parent if necessary.
    ///
    /// This allows the router to perform navigation actions.
    public func activate() {
        parentRouter?.childRouter = self
        parentRouter?.deactivate()
        self.isActive = true
        logger.log(.activate, isActive: isActive)
    }

    /// Deactivates this router and reactivates the parent router, if available.
    ///
    /// Used when dismissing modal content or transitioning focus.
    public func deactivate() {
        self.isActive = false
        self.parentRouter?.activate()
        self.parentRouter?.childRouter = nil
        logger.log(.deactivate, isActive: isActive)
    }
}
