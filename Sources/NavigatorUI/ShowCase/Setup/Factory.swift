//
//  Factory.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import SwiftUI

@MainActor
struct ExampleFactory {
    @ViewBuilder
    func build(_ destination: ExamplePushDestination) -> some View {
        switch destination {
        case .profile(let userID):
            ProfileView(userID: userID)
        case .settings:
            SettingsView()
        case .details(let itemID):
            DetailsView(itemID: itemID)
        }
    }

    @ViewBuilder
    func build(_ destination: ExampleSheetDestination) -> some View {
        switch destination {
        case .editProfile:
            EditProfileSheet()
        case .filterOptions:
            FilterOptionsSheet()
        }
    }

    @ViewBuilder
    func build(_ destination: ExampleFullScreenDestination) -> some View {
        switch destination {
        case .onboarding:
            OnboardingView()
        case .imageViewer(let url):
            ImageViewer(url: url)
        }
    }
}
