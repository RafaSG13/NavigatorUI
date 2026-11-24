# Repository Guidelines

## Project Overview
NavigatorUI is a SwiftUI navigation library for iOS 16+, shipped as a Swift Package (`Package.swift`, swift-tools-version 6.1, Swift 6 language mode, one library product `NavigatorUI`, no dependencies). It does **not** use `NavigationStack`. Every stack is a `UINavigationController` and every screen a `UIHostingController`, which gives an inspectable stack, pop interception, serialized transitions and custom animations.

## Architecture & Data Flow
- **Routes** (`Core/Route.swift`): `Route` is `Hashable`. `AnyRoute` is the type-erased form used in stack inspection and deep-link steps. Presentation (push / sheet / full screen) is chosen at the call site, never in the route type.
- **RouteRegistry** (`Core/RouteRegistry.swift`): maps a route *type* to a view builder. Views are built once, when pushed or presented. Feature modules register their own route types; registries combine with `include(_:)`.
- **Navigator** (`Navigator/`): `@MainActor ObservableObject` for one stack (the root stack or one modal). Screens read it with `@Environment(\.navigator)`. Public API lives in `Navigator.swift`; `Navigator+Operations.swift` holds the `...Now` methods that act immediately; `Navigator+Bookkeeping.swift` is the glue the UIKit layer calls.
  - A child `Navigator` is created per presented modal (`parent`, weak `presented`). It shares one `NavigationContext` (registry, deep links, event handler, queue, screen decorator) with the whole tree.
  - A navigator only touches its own stack. `present` from a covered stack presents on the topmost visible modal (`topmost`).
- **NavigationQueue** (`Core/NavigationQueue.swift`): every public call is enqueued and runs one at a time. An operation reports completion when its transition ends. The queue is blocked until the root `StackController` has appeared (`viewDidAppear`), so calls made before the UI exists run later. A 2 s watchdog abandons an operation that never reports completion and reports a `.failure`.
- **UIKit layer** (`UIKit/`):
  - `StackController`: `UINavigationController` subclass. It is the navigation delegate (stack sync, custom transitions), the swipe-back gesture delegate (pop guards) and the presentation delegate (interactive sheet dismissal).
  - `RouteHostingController`: one screen. Injects the navigator into the environment and exposes the screen's pop guard. Sets `navigationItem.backAction` so the system back button runs the guard.
  - `NavigationRoot`: the public SwiftUI entry point (`View` wrapping a `UIViewControllerRepresentable`). Also handles `onOpenURL` and universal links.
  - `NavigatorEnvironment.swift`: the `\.navigator` key (an inert navigator by default, so Previews do not crash) and the `.popGuard` modifier (a `PreferenceKey`).
- **Deep links** (`DeepLink/DeepLinkRouter.swift`): pattern table (`profile/:id`, `*`). Handlers return `[NavigationStep]` (push or present). Steps after a presentation apply inside the new modal. Strategies: `.replaceStack` (default) or `.append`.
- **Events / logging** (`Core/NavigationEvent.swift`): `NavigationContext.emit` feeds `Navigator.eventHandler`; `fail` also logs through `os.Logger`.

Flow: call (`push`, `present`, `open`, ...) → `Navigator` enqueues → `...Now` mutates the `StackController` → `afterApplied` waits until UIKit has really applied it and its transition ends → `finish()` starts the next operation → `syncStack()` updates `routes` / `depth`.

## Key Directories
- `Sources/NavigatorUI/Core/`: route, registry, presentation options, events, queue.
- `Sources/NavigatorUI/Navigator/`: the `Navigator` class (3 files).
- `Sources/NavigatorUI/UIKit/`: controllers, `NavigationRoot`, environment key, fade animator.
- `Sources/NavigatorUI/DeepLink/`: `DeepLinkRouter`, `NavigationStep`, `DeepLinkMatch`.
- `Tests/NavigatorUITests/`: Swift Testing suites and `Harness.swift`.
- `Example/`: runnable app project (see below), UI tests, and the project generator.

## Development Commands
The package is iOS-only (UIKit), so plain `swift build` is not the right check.
```sh
# build
xcodebuild -scheme NavigatorUI -destination 'generic/platform=iOS Simulator' build

# unit tests, headless (modal and animation tests are skipped, see Testing)
xcodebuild -scheme NavigatorUI -destination 'platform=iOS Simulator,name=iPhone 17' test

# everything: same unit tests inside the app + UI tests of the real app
xcodebuild -project Example/NavigatorUIExample.xcodeproj -scheme NavigatorUIExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# lint (global swiftlint, 120-column lines, 400-line files, 350-line types)
swiftlint lint --quiet Sources Tests Example
```
- `xcodebuild test` can keep running after it prints results (the simulator test host lingers). Read the results, then kill it.
- `Example/NavigatorUIExample.xcodeproj` is generated: `GEM_HOME=<cocoapods libexec> ruby Example/generate_project.rb` (needs the `xcodeproj` gem, which ships with Homebrew CocoaPods). Re-run it after adding or removing files in `Tests/NavigatorUITests/` or `Example/`, since the project lists files explicitly.

## Code Conventions & Common Patterns
- **Edit tooling hazard**: line-anchored edits on a file you have not just re-read have corrupted files here more than once. Re-read before editing, or rewrite the file.
- **Concurrency**: `Navigator`, `RouteRegistry`, `NavigationQueue`, `DeepLinkRouter` and all UIKit types are `@MainActor`. Closures stored by the library are `@MainActor`. UIKit completion handlers re-enter with `MainActor.assumeIsolated`.
- **Navigation calls are fire-and-forget and ordered.** Never call UIKit navigation directly from a new feature; add a `...Now` method plus a queued public wrapper. Operations must call `finish` exactly once.
- **UIKit defers same-turn pushes.** A push or pop issued in the same run-loop turn as another returns with `viewControllers` unchanged and no transition coordinator. Completion must therefore wait on a real "applied" predicate (`StackController.afterApplied`), never on "no coordinator".
- **Dismiss from the presenter**: `UIViewController.dismiss` on a modal that has its own presented modal dismisses only the inner one. Always call it on the presenting controller (`dismissPresentedNow`).
- **Weak references**: `Navigator.controller`, `parent` and `presented` are weak (the controllers own the view tree). Queue completions capture the queue `weak`: UIKit completions can fire after teardown.
- **Errors**: no throwing APIs. A bad call logs and emits `.failure(...)` and leaves state unchanged.
- **Access control**: public API only on `Navigator`, `NavigationRoot`, `RouteRegistry`, `Route`/`AnyRoute`, `Presentation`, `NavigationTransition`, `DeepLinkRouter` and friends, `NavigationEvent`, the `\.navigator` key and `.popGuard`. Everything else is internal. `routes` / `depth` are `public internal(set)` because the bookkeeping extension lives in another file.
- **Documentation**: public API carries `///` docs. Update `README.md` when public behavior changes.
- **Style**: 4 spaces, 120 columns, swiftlint clean.

## Important Files
- `Sources/NavigatorUI/Navigator/Navigator.swift`: the public navigation API.
- `Sources/NavigatorUI/Navigator/Navigator+Operations.swift`: how each operation drives UIKit.
- `Sources/NavigatorUI/UIKit/StackController.swift`: delegates, `afterApplied`, presentation styling.
- `Sources/NavigatorUI/Core/NavigationQueue.swift`: serialization and watchdog.
- `Example/NavigatorUIExample/`: the reference usage (`AppRoute.swift` shows registry + deep links).
- `Tests/NavigatorUITests/Harness.swift`: a real navigation tree in a real window.

## Runtime/Tooling Preferences
- Xcode with Swift 6.1+, iOS 16+ SDK. SwiftPM only. Apple frameworks only (`SwiftUI`, `UIKit`, `OSLog`, `Foundation`). No third-party dependencies unless asked.
- `.gitignore` excludes `.build/`, `DerivedData/`, `xcuserdata/`, `.DS_Store`.

## Testing & QA
- **Headless limits.** A bare package test process has no window scene. There, even plain UIKit `present` never completes. Tests that present, dismiss or animate are marked `.requiresScene` and run only through the Example app scheme (`Harness.isHosted`). They are skipped, not failing, in the package scheme.
- **Harness** attaches its window to the app's real `UIWindowScene` when hosted. A scene-less window in an app with scenes does not drive SwiftUI updates, so preferences (`popGuard`) never arrive.
- **UI tests** (`Example/NavigatorUIExampleUITests`) cover what unit tests cannot: real back-button and swipe-back guarding, deep links, sheets and full-screen covers, the fade transition, `setStack`. In UI tests, `Toggle` elements span the full row, so tap their trailing edge, not the center.
- Not yet covered by any test: interactive sheet swipe-dismiss `onDismiss`, `isDismissDisabled` / `onDismissAttempt`, `.crossDissolve`/`.flipHorizontal` covers, universal links, `NavigationRoot` environment decoration.

## Gotchas
- Screens must not contain their own `NavigationStack`.
- Environment objects set above `NavigationRoot` do not reach screens (UIKit hosting). They are injected with `NavigationRoot.decorateScreens`. [INFERENCE] This is based on how `UIHostingController` is known to behave; no test here asserts it.
- Screens are built once when pushed. State that must update later has to live in the screen (or be observed by it).
- `setStack` and `.replaceStack` deep links bypass pop guards on purpose.
- `NavigationTransition` animators are skipped for interactive swipe-back so the gesture keeps working.
- Tabs, `NavigationSplitView`, popovers, alerts as routes, results returned from modals and state restoration are not implemented.
- The repo has no CI and no version tags (README installs from `branch: "main"`).
