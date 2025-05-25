//
//  ShowCaseDestinations.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import SwiftUI

// MARK: - Full Screen Destinations

enum ExampleFullScreenDestination: FullScreenCoverDestination {
    case onboarding
    case imageViewer(url: String)

    var id: String { String(describing: self) }
}

struct OnboardingView: View {
    @EnvironmentObject var router: Router<ExamplePushDestination, ExampleSheetDestination, ExampleFullScreenDestination>

    var body: some View {
        VStack(spacing: 24) {
            Text("🚀 Welcome to the App")
                .font(.largeTitle)

            Button("Go to Settings (Push)") {
                router.push(.settings)
            }

            Button("Close Onboarding") {
                router.dismissFullScreenCover()
            }
        }
        .padding()
    }
}

struct ImageViewer: View {
    @EnvironmentObject var router: Router<ExamplePushDestination, ExampleSheetDestination, ExampleFullScreenDestination>
    let url: String

    var body: some View {
        VStack(spacing: 24) {
            Text("🖼 Image Viewer")
                .font(.title)

            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
            } placeholder: {
                ProgressView()
            }

            Button("Push to Profile") {
                router.push(.profile(userID: "viewerUser"))
            }

            Button("Dismiss Image Viewer") {
                router.dismissFullScreenCover()
            }
        }
        .padding()
    }
}
