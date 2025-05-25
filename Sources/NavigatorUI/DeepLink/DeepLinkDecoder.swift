//
//  DeepLinkDecoder.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import Foundation

/// A type-safe deep link decoder that converts URLs into navigable destinations.
///
/// This generic structure allows you to define custom decoding logic that maps `URL`s
/// into your app's navigation destinations. It's parameterized over the specific types
/// of destinations your app supports:
/// - `P`: The type used for push navigation destinations.
/// - `S`: The type used for sheet presentation destinations.
/// - `F`: The type used for full-screen cover destinations.
///
/// You inject the decoding behavior via a closure, giving you full control over how URLs are interpreted.
public struct DeepLinkDecoder<P: PushDestination, S: SheetDestination, F: FullScreenCoverDestination> {

    /// A closure responsible for converting a `URL` into a `Destination` if applicable.
    ///
    /// This function should return `nil` if the URL does not match any known navigation route.
    let parse: (URL) -> Destination<P, F, S>?

    /// Decodes a given URL into a navigation `Destination`, if recognized.
    ///
    /// This is a thin wrapper around the injected `parse` function.
    ///
    /// - Parameter url: The incoming deep link URL.
    /// - Returns: A `Destination` matching the URL, or `nil` if no match is found.
    func decode(url: URL) -> Destination<P, F, S>? {
        parse(url)
    }
}
