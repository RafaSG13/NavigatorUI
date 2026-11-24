# Security Policy

## Reporting a vulnerability

Do not open a public issue. Report privately through GitHub (**Security → Report a vulnerability**) or by email to rafasrrg13@gmail.com.

Include the impact, steps to reproduce with the iOS and Xcode versions, and a suggested fix if you have one.

## Scope

In scope:

- A crafted URL that crashes an app, or reaches a screen the handler did not intend, through `DeepLinkRouter` matching (pattern, host or path, or query handling).
- Bypassing a pop guard through a path that the [README](README.md#pop-guards) says consults guards.
- Navigation state corrupted by a sequence of calls.

Out of scope:

- App-level authorization of deep-linked screens. Handlers must validate parameters and return `nil` for anything they do not accept.
- `.replaceStack` deep links and `setStack` ignoring pop guards. This is documented behavior.
- URLs that the system delivers to `onOpenURL`; their origin is the system's concern.

## Supported versions

NavigatorUI is pre-1.0 and untagged. Only `main` receives fixes, and the API may change.
