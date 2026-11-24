import NavigatorUI
import SwiftUI

enum AppRoute: Route {
    case home
    case profile(id: String)
    case settings
    case details(id: Int)
    case editor
    case filters
    case onboarding
}

/// Everything the example registers with NavigatorUI, in one place.
@MainActor
enum AppNavigation {
    static let registry: RouteRegistry = {
        let registry = RouteRegistry()
        registry.register(AppRoute.self) { route in
            switch route {
            case .home: HomeView()
            case .profile(let id): ProfileView(id: id)
            case .settings: SettingsView()
            case .details(let id): DetailsView(id: id)
            case .editor: EditorView()
            case .filters: FiltersView()
            case .onboarding: OnboardingView()
            }
        }
        return registry
    }()

    /// Patterns work for `navigatorui://profile/42` and `https://example.com/profile/42` alike.
    static let deepLinks: DeepLinkRouter = {
        let links = DeepLinkRouter()
        links.register("profile/:id") { [.push(AppRoute.profile(id: $0["id"] ?? ""))] }
        links.register("profile/:id/settings") { match in
            [.push(AppRoute.profile(id: match["id"] ?? "")), .push(AppRoute.settings)]
        }
        links.register("details/:id") { match in
            match.int("id").map { [.push(AppRoute.details(id: $0))] }
        }
        links.register("settings", push: { _ in AppRoute.settings })
        links.register("editor") { _ in [.present(AppRoute.editor, style: .sheet(detents: [.medium, .large]))] }
        links.register("editor/profile/:id") { match in
            [.present(AppRoute.editor), .push(AppRoute.profile(id: match["id"] ?? ""))]
        }
        links.register("onboarding") { _ in [.present(AppRoute.onboarding, style: .fullScreen())] }
        return links
    }()
}
