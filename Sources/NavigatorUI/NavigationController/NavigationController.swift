//
//  NavigationController.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 24/5/25.
//

import SwiftUI

/// A container view that manages navigation using `NavigationStack`, `.sheet`, and `.fullScreenCover`,
/// coordinated via a `Router` object.
///
/// `NavigationController` is the core of the `NavigatorUI`, enabling nested and modular navigation.
/// It supports push navigation, sheet modals, and full screen covers with view factories.
///
/// - Parameters:
///   - P: Type conforming to `PushDestination` representing push navigation destinations.
///   - S: Type conforming to `SheetDestination` representing sheet modal destinations.
///   - F: Type conforming to `FullScreenCoverDestination` representing full screen cover destinations.
///   - Content: The root content view displayed inside the navigation stack.
///   - PushView: The view type returned for push destinations.
///   - SheetView: The view type returned for sheet destinations.
///   - FullScreenView: The view type returned for full screen cover destinations.
public struct NavigationController<
    P: PushDestination,
    S: SheetDestination,
    F: FullScreenCoverDestination,
    Content: View,
    PushView: View,
    SheetView: View,
    FullScreenView: View
>: View {

    @StateObject private var router: Router<P, S, F>
    private let decoder: DeepLinkDecoder<P, S, F>
    private let content: () -> Content
    private let pushFactory: (P) -> PushView
    private let sheetFactory: (S) -> SheetView
    private let fullScreenFactory: (F) -> FullScreenView

    /// Creates a new `NavigationController`.
    ///
    /// - Parameters:
    ///   - parent: An optional parent router to support nested navigation.
    ///   - decoder: A deep link decoder to handle incoming URLs.
    ///   - pushFactory: A view builder that returns a view for a given push destination.
    ///   - sheetFactory: A view builder that returns a view for a given sheet destination.
    ///   - fullScreenFactory: A view builder that returns a view for a given full screen cover destination.
    ///   - content: The root view content to be displayed inside the navigation stack.
    public init(parent: Router<P, S, F>? = nil,
                decoder: DeepLinkDecoder<P, S, F>,
                @ViewBuilder pushFactory: @escaping (P) -> PushView,
                @ViewBuilder sheetFactory: @escaping (S) -> SheetView,
                @ViewBuilder fullScreenFactory: @escaping (F) -> FullScreenView,
                @ViewBuilder _ content: @escaping () -> Content) {
        self._router = StateObject(wrappedValue: Router(parent: parent))
        self.decoder = decoder
        self.content = content
        self.pushFactory = pushFactory
        self.sheetFactory = sheetFactory
        self.fullScreenFactory = fullScreenFactory
    }

    /// The view body for `NavigationController`.
    ///
    /// This sets up a `NavigationStack` with push navigation,
    /// sheets, and full screen covers, all coordinated through the internal `Router`.
    /// It also listens for incoming deep link URLs and forwards them to the router.
    public var body: some View {
        NavigationStack(path: $router.navigationPath) {
            content()
                .navigationDestination(for: P.self) { destination in
                    pushFactory(destination)
                }
        }
        .sheet(item: $router.currentSheet) { destination in
            navigationView(
                parent: router,
                decoder: decoder,
                pushFactory: pushFactory,
                sheetFactory: sheetFactory,
                fullScreenFactory: fullScreenFactory
            ) {
                sheetFactory(destination)
            }
        }
        .fullScreenCover(item: $router.currentFullScreenCover) { destination in
            navigationView(
                parent: router,
                decoder: decoder,
                pushFactory: pushFactory,
                sheetFactory: sheetFactory,
                fullScreenFactory: fullScreenFactory
            ) {
                fullScreenFactory(destination)
            }
        }
        .onOpenURL { url in
            router.didReceiveDeepLink(url: url, decoder: decoder)
        }
        .environmentObject(router)
        .onAppear { router.activate() }
        .onDisappear { router.deactivate() }
    }
}
