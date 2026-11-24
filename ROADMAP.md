# Roadmap and Known Issues

Status of NavigatorUI after the UIKit rewrite. "Verified" means covered by a passing test run; everything else is a risk, not a known fact.

## Possible bugs and risks

Ordered by how likely they are to bite a real app.

| # | Area | Risk | Status |
|---|---|---|---|
| 1 | Sheet swipe-dismiss | `onDismiss` for interactive dismissal relies on `presentationControllerDidDismiss`; only simulated in unit tests, never driven by a real swipe. Nested modals above a swiped sheet are finished recursively, also untested for real. | Untested |
| 2 | `isDismissDisabled` / `onDismissAttempt` | Wired to `isModalInPresentation` and `presentationControllerDidAttemptToDismiss`. No test. | Untested |
| 3 | Environment bridging | Environment objects above `NavigationRoot` are assumed not to reach UIKit-hosted screens (hence `decorateScreens`). Not asserted by any test; a screen reading a missing `@EnvironmentObject` crashes. | Inferred |
| 4 | Universal links | `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` is attached but never exercised. | Untested |
| 5 | Stale screens | Screens are built once when pushed. State from the parent that changes later does not re-render a pushed screen unless it observes that state itself. Easy to misuse. | By design |
| 6 | Queue watchdog | An operation that never completes is abandoned after 2 s and later operations proceed, possibly while UIKit is still mid-transition. Slow devices or very long custom animators could trip it. | Unverified under load |
| 7 | Deferred-push wait | `afterApplied` polls every 5 ms for up to 400 tries (about 2 s). Timing based. | Verified only on iPhone 17 simulator |
| 8 | External UIKit calls | Anything that pushes or presents outside the Navigator (system share sheets, alerts from UIKit code, other libraries) is invisible to the queue. `present` fails with a logged `.failure` when something foreign is already presented. | By design |
| 9 | Custom transitions | Animators are skipped during interactive swipe-back so the gesture works. A custom pop animation therefore does not apply to swipe-back. | By design |
| 10 | Pop guard side effects | Guards run inside `gestureRecognizerShouldBegin` and for every removed screen on multi-pop. A guard that shows UI may fire more than once per attempt. | Unverified |
| 11 | Deep links vs. guards | `.replaceStack` and `setStack` bypass pop guards on purpose, so a deep link can discard unsaved work. | By design |
| 12 | Multi-window / iPad scenes | One `Navigator` per `NavigationRoot`. `onOpenURL` is delivered per scene; behavior with several windows is untested. | Untested |
| 13 | Layout | `NavigationRoot` uses `.ignoresSafeArea()` and relies on the nav controller for insets. Only checked on an iPhone simulator, no iPad, landscape or Dynamic Type pass. | Partially seen |
| 14 | `StackController` back handling | The system back button is intercepted through `navigationItem.backAction`. Long-press back-menu behavior and title display were not inspected. | Unverified |
| 15 | Platforms | iOS only. No `#if canImport(UIKit)` guards; `swift build` on macOS fails. Mac Catalyst and visionOS untested. | Known |
| 16 | Process | No CI, no version tags, README installs from `branch: "main"`. Package tests need the Example app scheme for full coverage. | Known |

## Roadmap

### Next (close the gaps above)
1. **UI tests for the untested paths:** swipe-dismiss with `onDismiss`, `isDismissDisabled` with `onDismissAttempt`, cover transition styles, a screen reading a missing environment object (to turn risk 3 into a fact).
2. **CI:** GitHub Actions running the package scheme and the Example app scheme (hosted tests + UI tests) on a simulator.
3. **Release hygiene:** tag `0.1.0`, switch README install to a version, add a CHANGELOG.
4. **Guard semantics:** decide and document whether a guard may run more than once per user attempt; add a test.

### Then (features)
1. **Tabs:** a `TabRoot` with one `Navigator` per tab, selected-tab state, deep links that switch tab, re-tap to pop to root. The old `TabDestination` stub never worked and was removed.
2. **Results from modals:** `let value = await navigator.present(route, returning: T.self)`, built on the existing `onDismiss` plumbing.
3. **State restoration:** optional `Codable` route registration so stacks and modals survive relaunch.
4. **Popovers, alerts and confirmation dialogs as presentations**, with iPad popover anchoring.
5. **`NavigationSplitView` equivalent** for iPad and Mac Catalyst.
6. **Navigation events as `AsyncStream`** in addition to the handler closure.

### Later / maybe
- Interactive custom transitions (including swipe-back for custom animators).
- `@Observable` navigator and `@Entry` environment if the minimum moves to iOS 17.
- Async deep-link handlers (auth-gated routes, pending-link queue while signed out).
- macOS / visionOS support behind `#if` guards.
- Lower `swift-tools-version` to 6.0 if consumers on older Xcode matter.

## Out of scope
- Replacing UIKit navigation with a pure SwiftUI container (rejected: loses system back swipe, bars and accessibility).
- Third-party dependencies.
