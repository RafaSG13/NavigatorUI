//
//  PushDestinations.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import SwiftUI

// MARK: - Push Destinations

enum ExamplePushDestination: PushDestination {
    case profile(userID: String)
    case settings
    case details(itemID: Int)
}

struct ProfileView: View {
    @EnvironmentObject var router: Router<ExamplePushDestination, ExampleSheetDestination, ExampleFullScreenDestination>
    let userID: String

    var body: some View {
        VStack(spacing: 16) {
            Text("👤 Profile View")
                .font(.title)
            Text("User ID: \(userID)")

            Button("Edit Profile (Sheet)") {
                router.presentSheet(.editProfile)
            }

            Button("View Onboarding (FullScreen)") {
                router.presentFullScreenCover(.onboarding)
            }
        }
        .padding()
    }
}

struct SettingsView: View {
    @EnvironmentObject var router: Router<ExamplePushDestination, ExampleSheetDestination, ExampleFullScreenDestination>

    var body: some View {
        VStack(spacing: 16) {
            Text("⚙️ Settings")
                .font(.title)

            Button("Push Details from Settings") {
                router.push(.details(itemID: 777))
            }

            Button("Present Edit Profile (Sheet)") {
                router.presentSheet(.editProfile)
            }
        }
        .padding()
    }
}

struct DetailsView: View {
    @EnvironmentObject var router: Router<ExamplePushDestination, ExampleSheetDestination, ExampleFullScreenDestination>
    let itemID: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("📦 Item Details")
                .font(.title)
            Text("Item ID: \(itemID)")

            Button("Show Filters (Sheet)") {
                router.presentSheet(.filterOptions)
            }

            Button("Open Image Viewer (FullScreen)") {
                router.presentFullScreenCover(.imageViewer(url: "https://picsum.photos/300"))
            }
        }
        .padding()
    }
}
