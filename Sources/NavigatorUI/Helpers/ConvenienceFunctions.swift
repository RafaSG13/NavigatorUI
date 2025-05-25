//
//  Functions.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import SwiftUI

/// Convenience function that wraps content in a nested `NavigationController`.
/// Useful for rendering views inside modals or full screen covers with their own navigation context.
///
/// - Parameters:
///   - parent: The parent router this navigation context is derived from.
///   - decoder: The deep link decoder to use.
///   - pushFactory: Factory for push destinations.
///   - sheetFactory: Factory for sheet destinations.
///   - fullScreenFactory: Factory for full screen destinations.
///   - content: The root content inside this navigation context.
@MainActor @ViewBuilder
func navigationView<
    P: PushDestination,
    S: SheetDestination,
    F: FullScreenCoverDestination,
    Content: View,
    PushView: View,
    SheetView: View,
    FullScreenView: View
>(
    parent: Router<P, S, F>,
    decoder: DeepLinkDecoder<P, S, F>,
    @ViewBuilder pushFactory: @escaping (P) -> PushView,
    @ViewBuilder sheetFactory: @escaping (S) -> SheetView,
    @ViewBuilder fullScreenFactory: @escaping (F) -> FullScreenView,
    @ViewBuilder content: @escaping () -> Content
) -> some View {
    NavigationController(
        parent: parent,
        decoder: decoder,
        pushFactory: pushFactory,
        sheetFactory: sheetFactory,
        fullScreenFactory: fullScreenFactory,
        content
    )
}


@MainActor
func handleDeepLink<P: PushDestination, S: SheetDestination, F: FullScreenCoverDestination>(
    url: URL,
    decoder: DeepLinkDecoder<P, S, F>,
    router: Router<P, S, F>
) {
    guard let destination = decoder.decode(url: url) else {
        print("Failed to decode deep link for URL: \(url)")
        return
    }

    switch destination {
    case .push(let dest):
        router.push(dest)
    case .sheet(let dest):
        router.presentSheet(dest)
    case .fullScreenCover(let dest):
        router.presentFullScreenCover(dest)
    }
}
