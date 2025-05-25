//
//  Decoder.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import Foundation

extension ExamplePushDestination {
    static func decode(from segments: [String]) -> ExamplePushDestination? {
        guard let first = segments.first?.lowercased() else { return nil }

        switch first {
        case "profile":
            guard segments.count >= 2 else { return nil }
            return .profile(userID: segments[1])
        case "settings":
            return .settings
        case "details":
            guard segments.count >= 2, let id = Int(segments[1]) else { return nil }
            return .details(itemID: id)
        default:
            return nil
        }
    }
}

extension ExampleSheetDestination {
    static func decode(from segments: [String]) -> ExampleSheetDestination? {
        guard let first = segments.first?.lowercased() else { return nil }

        switch first {
        case "editprofile":
            return .editProfile
        case "filteroptions":
            return .filterOptions
        default:
            return nil
        }
    }
}

extension ExampleFullScreenDestination {
    static func decode(from segments: [String]) -> ExampleFullScreenDestination? {
        guard let first = segments.first?.lowercased() else { return nil }

        switch first {
        case "onboarding":
            return .onboarding
        case "imageviewer":
            guard segments.count >= 2 else { return nil }
            return .imageViewer(url: segments[1])
        default:
            return nil
        }
    }
}

/// A concrete implementation of a deep link decoder for the app's navigation system.
///
/// This decoder is responsible for converting a given `URL` into a valid `Destination`,
/// matching against registered `Push`, `Sheet`, and `FullScreenCover` destinations.
struct CustomDeepLinkDecoder {

    /// The public-facing decoder, exposed as a `DeepLinkDecoder` instance.
    ///
    /// Internally, it uses the static `decode(_:)` method to perform the parsing logic.
    var decoder: DeepLinkDecoder = DeepLinkDecoder(parse: decode(_:))

    /// Attempts to decode a given URL into a typed navigation `Destination`.
    ///
    /// The method parses the URL into path components, filters them,
    /// and tries to match them against known destination decoders:
    /// - `ExamplePushDestination`
    /// - `ExampleSheetDestination`
    /// - `ExampleFullScreenDestination`
    ///
    /// The first successful match will be returned.
    ///
    /// - Parameter url: The incoming deep link URL to evaluate.
    /// - Returns: A type-safe `Destination` if decoding succeeds, otherwise `nil`.
    static func decode(_ url: URL) -> Destination<ExamplePushDestination, ExampleFullScreenDestination, ExampleSheetDestination>? {
        // Break the URL into relevant path segments, skipping slashes and empty strings
        let segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        // Attempt to decode using each destination type, in priority order
        let candidates: [Destination<ExamplePushDestination, ExampleFullScreenDestination, ExampleSheetDestination>?] = [
            ExamplePushDestination.decode(from: segments).map { .push($0) },
            ExampleSheetDestination.decode(from: segments).map { .sheet($0) },
            ExampleFullScreenDestination.decode(from: segments).map { .fullScreenCover($0) }
        ]

        // Return the first successful decoding
        return candidates.compactMap { $0 }.first
    }
}

