//
//  SheetDestinations.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import SwiftUI

// MARK: - Sheet Destinations

enum ExampleSheetDestination: SheetDestination {
    case editProfile
    case filterOptions

    var id: String { String(describing: self) }
}

struct EditProfileSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("✏️ Edit Profile")
                .font(.title)
            TextField("Name", text: .constant("Rafa"))
                .textFieldStyle(.roundedBorder)
                .padding()
        }
        .padding()
    }
}

struct FilterOptionsSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("🔍 Filter Options")
                .font(.title)
            Toggle("Only Favorites", isOn: .constant(true))
        }
        .padding()
    }
}

