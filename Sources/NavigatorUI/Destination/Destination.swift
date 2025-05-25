//
//  Destination.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 24/5/25.
//

import Foundation

/// Protocol for destinations used in push navigation.
/// Conforming types must be `Hashable` to be used with `NavigationPath`.
public protocol PushDestination: Hashable {}

/// Protocol for destinations presented as full screen covers.
/// Conforming types must be `Identifiable` for SwiftUI integration.
/// The `id` property distinguishes unique instances.
public protocol FullScreenCoverDestination: Identifiable {
    /// Unique identifier for the full screen cover destination.
    var id: String { get }
}

/// Protocol for destinations presented as sheets.
/// Conforming types must be `Identifiable` for SwiftUI integration.
/// The `id` property distinguishes unique instances.
public protocol SheetDestination: Identifiable {
    /// Unique identifier for the sheet destination.
    var id: String { get }
}

/// Protocol for destinations used in tab-based navigation.
public protocol TabDestination {}

/// Protocol for destinations that can be used with deep linking.
public protocol DeepLinkDestination {}

/// Represents a navigation destination, which can be one of:
/// - a push destination
/// - a full screen cover destination
/// - a sheet destination
///
/// Generic parameters:
/// - `P`: Type conforming to `PushDestination`
/// - `F`: Type conforming to `FullScreenCoverDestination`
/// - `S`: Type conforming to `SheetDestination`
public enum Destination<P: PushDestination, F: FullScreenCoverDestination, S: SheetDestination> {
    /// Represents a push navigation destination.
    case push(P)
    /// Represents a full screen cover destination.
    case fullScreenCover(F)
    /// Represents a sheet destination.
    case sheet(S)
}
