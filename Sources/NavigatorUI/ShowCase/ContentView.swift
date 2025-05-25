//
//  ContentView.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var router: Router<ExamplePushDestination, ExampleSheetDestination, ExampleFullScreenDestination>

    var body: some View {
        List {
            Section(header: Text("Push")) {
                Button("👤 Go to Profile") {
                    router.push(.profile(userID: "rafa123"))
                }
                Button("⚙️ Open Settings") {
                    router.push(.settings)
                }
                Button("📦 View Item Details") {
                    router.push(.details(itemID: 42))
                }
            }

            Section(header: Text("Sheets")) {
                Button("✏️ Edit Profile") {
                    router.presentSheet(.editProfile)
                }
                Button("🔍 Show Filters") {
                    router.presentSheet(.filterOptions)
                }
            }

            Section(header: Text("Full Screens")) {
                Button("🚀 Onboarding") {
                    router.presentFullScreenCover(.onboarding)
                }
                Button("🖼 View Image") {
                    router.presentFullScreenCover(.imageViewer(url: "https://picsum.photos/400"))
                }
            }

            Section(header: Text("Deep Links")) {
                Button("🔗 Open Deep Link") {
                    if let url = URL(string: "myapp://profile/123") {
                        UIApplication.shared.open(url)
                    }
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle("🎯 Navigation Showcase")
        .navigationBarTitleDisplayMode(.inline)
    }
}
