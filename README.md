# NavigatorUI

NavigatorUI is a Swift library designed to provide a robust and flexible navigation system for iOS applications. It supports advanced navigation patterns, deep linking, and modular destination management, making it easy to build scalable and maintainable navigation flows in SwiftUI projects.

## Features
- **Declarative Navigation:** Define navigation flows using SwiftUI paradigms.
- **Deep Linking:** Easily handle and decode deep links to navigate to specific destinations.
- **Destination Management:** Modularize navigation destinations for better code organization.
- **Custom Navigation Controllers:** Extend or customize navigation behaviors as needed.
- **Logging:** Integrated logging for navigation events and debugging.

## Directory Structure
- `DeepLink/` – Deep link decoding and handling.
- `Destination/` – Core destination definitions.
- `Helpers/` – Utility and convenience functions.
- `Logger/` – Logging utilities for navigation events.
- `NavigationController/` – Custom navigation controller logic.
- `Router/` – Main router and navigation logic.
- `ShowCase/` – Example usage and showcase of navigation patterns.

## Getting Started
1. Add NavigatorUI as a dependency in your `Package.swift`:
   ```swift
   .package(url: "<repo-url>", from: "1.0.0")
   ```
2. Import the library in your SwiftUI project:
   ```swift
   import NavigatorUI
   ```
3. Set up your destinations and router as shown in the `ShowCase` folder.

## Example
```swift
import NavigatorUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            // Use your router and destinations here
        }
    }
}
```

## Documentation
- Each module and public API is documented in the source code.
- See the `ShowCase` folder for practical examples.

## Requirements
- iOS 16+
- Swift 6.1+

## License
MIT License. See [LICENSE](LICENSE) for details.
