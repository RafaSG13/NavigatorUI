//
//  ShowCase.swift
//  NavigatorUI
//
//  Created by Rafael Serrano Gamarra on 25/5/25.
//

import SwiftUI

struct ShowCase: View {
    let factory = ExampleFactory()
    let deepLinkDecoder = CustomDeepLinkDecoder().decoder

    var body: some View {
        NavigationController(decoder: deepLinkDecoder,
                             pushFactory: factory.build,
                             sheetFactory: factory.build,
                             fullScreenFactory: factory.build) {
            ContentView()
        }
    }
}

#Preview {
    ShowCase()
}
