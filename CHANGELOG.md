# Changelog

All notable changes are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

This project has no tagged releases yet.

## [Unreleased]

### Added

- `Navigator` with queued `push`, `pop`, `popToRoot`, `pop(to:)`, `setStack`, `present`, `dismiss`, `dismissModal`, `dismissAll` and `open`, and observable `routes` and `depth`.
- `RouteRegistry` with `include(_:)` for feature modules.
- `NavigationRoot` with `decorateScreens`, `onOpenURL` and universal link handling.
- `.popGuard` for the back button, swipe-back and programmatic pops.
- Sheets (detents, grabber, `isDismissDisabled`, `onDismissAttempt`) and full-screen covers, both with `onDismiss`.
- `DeepLinkRouter` with URL patterns and the `.replaceStack` and `.append` strategies.
- `NavigationTransition` with a built-in `.fade`.
- `NavigationEvent` and `Navigator.eventHandler`.
- Example app and UI tests.
- Documentation: README, diagrams, `docs/ARCHITECTURE.md`, `CONTRIBUTING.md` and `SECURITY.md`.

### Changed

- Rewritten on `UINavigationController`; `NavigationStack` is no longer used.
- `ROADMAP.md` moved to `docs/ROADMAP.md`.

### Removed

- The non-functional `TabDestination` stub.
