# NavigatorUI

A navigation library for SwiftUI apps, built on `UINavigationController` instead of `NavigationStack`.

Every stack (the root and each sheet or full-screen cover) is a real `UINavigationController`, and every screen is a `UIHostingController`. That gives you what `NavigationStack` does not expose: an inspectable stack, pop interception, serialized transitions, and custom animations. Screens are still plain SwiftUI views.

- **One route type per feature.** `Route` is just `Hashable`. Push or present the same route; the presentation is chosen at the call site.
- **Inspect and edit the stack.** `routes`, `depth`, `pop(to:)`, `popToRoot()`, `setStack(_:)`.
- **Pop guards.** `.popGuard { ... }` blocks the back button, swipe-back and programmatic pops.
- **Safe call ordering.** Calls are queued and run one at a time, each after the previous transition ends. `push(a); push(b); present(c)` is safe, and so is calling before the UI exists.
- **Modals with their own stacks.** Sheets (detents, grabber, dismiss control) and full-screen covers, with `onDismiss`.
- **Deep links.** Pattern matching, multi-screen stacks, sheets followed by pushes inside them, universal links, cold start.
- **Custom transitions.** `.fade` built in, or bring your own `UIViewControllerAnimatedTransitioning`.
- **Events.** One handler receives every stack change, presentation, dismissal, blocked pop and failure.

Requires iOS 16+ and Swift 6.1 (Xcode 16.3+). No dependencies.

## Install

```swift
.package(url: "https://github.com/RafaSG13/NavigatorUI.git", branch: "main")
```

(No version tags exist yet.)

## Use

```swift
import NavigatorUI
import SwiftUI

enum AppRoute: Route {
    case home
    case profile(id: String)
    case editor
}

@main
struct MyApp: App {
    let registry: RouteRegistry = {
        let registry = RouteRegistry()
        registry.register(AppRoute.self) { route in
            switch route {
            case .home: HomeView()
            case .profile(let id): ProfileView(id: id)
            case .editor: EditorView()
            }
        }
        return registry
    }()

    var body: some Scene {
        WindowGroup {
            NavigationRoot(registry: registry, root: AppRoute.home)
        }
    }
}

struct HomeView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        List {
            Button("Profile") { navigator.push(AppRoute.profile(id: "42")) }
            Button("Edit") { navigator.present(AppRoute.editor, style: .sheet(detents: [.medium, .large])) }
        }
        .navigationTitle("Home") // titles and toolbars work as usual
    }
}
```

### Rules

- **Do not put a `NavigationStack` inside a screen.** `NavigationRoot` already provides the navigation controller.
- **Environment objects above `NavigationRoot` do not reach screens**, because screens are hosted in UIKit. Inject them with `.decorateScreens { $0.environmentObject(store) }`. Dark mode, dynamic type and layout direction pass through UIKit normally.
- **Screens are built once**, when pushed or presented. A screen that must react to later state owns or observes that state itself.
- **Views outside a `NavigationRoot`** (previews) get an inert navigator. Calls are dropped and logged, never crash.

### Stack

```swift
navigator.push(AppRoute.profile(id: "42"))
navigator.push(AppRoute.settings, transition: .fade)
navigator.pop()                              // or pop(3)
navigator.pop(to: AppRoute.home)
navigator.popToRoot()
navigator.setStack([AppRoute.home, AppRoute.profile(id: "42")]) // keeps matching screens
navigator.routes, navigator.depth            // observable
```

### Modals

```swift
navigator.present(AppRoute.editor)                                   // sheet
navigator.present(AppRoute.editor, style: .sheet(detents: [.medium, .large], showsGrabber: true))
navigator.present(AppRoute.onboarding, style: .fullScreen(), onDismiss: { ... })
navigator.dismiss()        // pops if the stack has more than its root, otherwise closes the modal
navigator.dismissModal()   // closes this modal whatever its depth
navigator.dismissAll()     // closes every modal
```

Each modal has its own `Navigator`. `push` from inside a sheet pushes inside the sheet. A navigator only affects its own stack, so `present` from a screen that is covered by a modal presents on top of the visible one.

### Pop guards

```swift
EditorView()
    .popGuard {
        guard model.hasUnsavedChanges else { return true }
        model.confirmingDiscard = true      // show your confirmation
        return false                        // refuse this pop
    }
// in the confirmation: navigator.pop(force: true)
```

Guards cover the back button, swipe-back, `pop`, `popToRoot`, `pop(to:)` and `dismiss`. `setStack` and `.replaceStack` deep links do not consult guards. Swipe-to-dismiss of a sheet is controlled with `.sheet(isDismissDisabled:onDismissAttempt:)`.

### Deep links

```swift
let links = DeepLinkRouter()
links.register("profile/:id") { [.push(AppRoute.profile(id: $0["id"] ?? ""))] }
links.register("profile/:id/settings") { match in
    [.push(AppRoute.profile(id: match["id"] ?? "")), .push(AppRoute.settings)]
}
links.register("editor/profile/:id") { match in
    // steps after a presentation apply inside the presented modal
    [.present(AppRoute.editor), .push(AppRoute.profile(id: match["id"] ?? ""))]
}

NavigationRoot(registry: registry, deepLinks: links, root: AppRoute.home)
```

`NavigationRoot` handles `onOpenURL` and universal links. To open URLs from elsewhere, create the `Navigator` yourself and pass it in: `NavigationRoot(navigator: navigator, ...)`, then call `navigator.open(url)`, even before the UI appears.

- **What is matched:** for custom schemes the host counts as the first segment, so `myapp://profile/123` and `myapp:///profile/123` both match `profile/:id`. For `http(s)` the host is ignored. `*` matches one segment; query items are on the match (`match["q"]`).
- **Strategy:** `.replaceStack` (default) dismisses modals and pops to the root first; `.append` applies on top of the current screens.

### Events

```swift
navigator.eventHandler = { event in ... } // .stackChanged, .presented, .dismissed, .popBlocked, .deepLink, .failure
```

## Example app and tests

`Example/NavigatorUIExample.xcodeproj` is a runnable app (URL scheme `navigatorui://`). Regenerate the project with `ruby Example/generate_project.rb` (needs the `xcodeproj` gem).

```sh
# Logic tests; modal and animation tests are skipped (a bare test process has no window scene)
xcodebuild -scheme NavigatorUI -destination 'platform=iOS Simulator,name=iPhone 17' test

# Everything: the same unit tests inside the app, plus UI tests of back button, swipe-back, sheets and URLs
xcodebuild -project Example/NavigatorUIExample.xcodeproj -scheme NavigatorUIExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Not covered yet

Tab bars and `NavigationSplitView`, results returned from modals, popovers and alerts as routes, and state restoration (routes are not required to be `Codable`).

## License

MIT. See [LICENSE](LICENSE).
