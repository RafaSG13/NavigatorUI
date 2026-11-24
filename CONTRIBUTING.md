# Contributing to NavigatorUI

Bug reports, fixes and items from [docs/ROADMAP.md](docs/ROADMAP.md) are welcome.

## Getting started

1. Clone the repository.
2. Open `Package.swift` in Xcode to work on the library, or `Example/NavigatorUIExample.xcodeproj` to work on the app.
3. You need Xcode 16.3+ (Swift 6.1) and an iOS 16+ simulator.

## Before you open a pull request

```sh
# build
xcodebuild -scheme NavigatorUI -destination 'generic/platform=iOS Simulator' build

# unit tests, headless (modal and animation tests are skipped)
xcodebuild -scheme NavigatorUI -destination 'platform=iOS Simulator,name=iPhone 17' test

# everything: the same unit tests inside the app, plus UI tests of the real app
xcodebuild -project Example/NavigatorUIExample.xcodeproj -scheme NavigatorUIExample \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# lint: must print nothing
swiftlint lint --quiet Sources Tests Example
```

`xcodebuild test` can keep running after it prints results (the simulator test host lingers); read the results, then stop it. Run the Example app and exercise the path you changed.

## Guidelines

- No third-party dependencies. Apple frameworks only (`SwiftUI`, `UIKit`, `OSLog`, `Foundation`).
- Every navigation call goes through the queue. Add a `...Now` method plus a queued public wrapper; never call UIKit navigation directly from a feature. An operation calls `finish` exactly once.
- Completion waits on `StackController.afterApplied`, never on "no transition coordinator": UIKit defers same-turn pushes.
- Dismiss from the presenter (`dismissPresentedNow`): `dismiss` on a modal that has its own modal closes only the inner one.
- `Navigator.controller`, `parent` and `presented` stay weak. UIKit completions capture the queue weakly and re-enter with `MainActor.assumeIsolated`.
- No throwing APIs. A bad call logs, emits `.failure(...)` and leaves state unchanged.
- The public surface is limited to `Navigator`, `NavigationRoot`, `RouteRegistry`, `Route`/`AnyRoute`, `Presentation`, `NavigationTransition`, `DeepLinkRouter` and friends, `NavigationEvent`, the `\.navigator` key and `.popGuard`. Everything else is internal.
- Public API carries `///` docs, and `README.md` is updated when public behavior changes. Update `docs/ARCHITECTURE.md` when internals change.
- `@MainActor` everywhere UIKit is touched. Closures stored by the library are `@MainActor`.
- 4-space indent, 120 columns, swiftlint clean.
- Tests use Swift Testing and check observable behavior. Mark tests that present, dismiss or animate `.requiresScene`.
- After adding or removing files in `Tests/NavigatorUITests/` or `Example/`, regenerate the project: `GEM_HOME=<cocoapods libexec> ruby Example/generate_project.rb` (needs the `xcodeproj` gem, which ships with Homebrew CocoaPods).

## Reporting bugs

Include the iOS version, device or simulator, Xcode version, a minimal route and registry that reproduces the problem, and the sequence of events from `navigator.eventHandler`. Security issues go through [SECURITY.md](SECURITY.md), not public issues.

## Commit messages

A short imperative subject, with a body that explains the why. Add user-visible changes to [CHANGELOG.md](CHANGELOG.md) under **Unreleased**.

## Releases

Nothing is tagged yet. Tagging `0.1.0` is tracked in [docs/ROADMAP.md](docs/ROADMAP.md).
