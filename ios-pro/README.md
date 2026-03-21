# iOS Development Pro Skill

Professional iOS development following 2024-2026 best practices.

## Stack Recommendations

### Small Apps (<10 screens)
- SwiftUI + MVVM
- URLSession + async/await
- SwiftData (iOS 17+)
- NavigationStack

### Medium Apps (10-20 screens)
- SwiftUI + MVVM + Coordinator
- URLSession + async/await
- SwiftData or Core Data
- Dependency Injection (Factory)

### Large Apps (20+ screens)
- SwiftUI + TCA (Composable Architecture)
- Alamofire + Moya
- Core Data + caching layer
- TCA Navigation

## Trending UI (2024-2026)

**Glassmorphism** - Primary trend:
```swift
.background(.ultraThinMaterial)
.cornerRadius(16)
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
)
```

## Essential Tools

- **XcodeGen/Tuist**: Project generation
- **SwiftGen**: Type-safe resources (9.2k stars)
- **Fastlane**: Build/deploy automation
- **SwiftLint**: Code quality
- **Lottie**: Animations (native SwiftUI 4.3+)
- **Kingfisher**: Image caching (pure Swift)

## Dependencies

**Always use Swift Package Manager (SPM), never CocoaPods**

Popular libraries:
- Alamofire (42k stars) - Networking
- Kingfisher (23k stars) - Image loading
- Lottie (25k stars) - Animations
- SnapKit (20k stars) - Auto Layout DSL
- SwiftLint (18k stars) - Linting

## Build Configuration

### project.yml (XcodeGen)
```yaml
name: YourApp
options:
  bundleIdPrefix: com.yourcompany
  deploymentTarget:
    iOS: 17.0
settings:
  SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"
  SUPPORTS_MACCATALYST: false
  SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: false

targets:
  YourApp:
    type: application
    platform: iOS
    sources: [Sources]

  YourAppTests:
    type: bundle.unit-test
    platform: iOS
    sources: [Tests]
```

### Fastfile
```ruby
default_platform(:ios)

platform :ios do
  desc "Build and run on simulator"
  lane :sim do
    scan(
      scheme: "YourApp",
      destination: "platform=iOS Simulator,name=iPhone 15 Pro"
    )
  end

  desc "Run tests"
  lane :test do
    scan(scheme: "YourApp")
  end
end
```

## Critical Build Rules

1. **UNIQUE FILENAMES**: Every .swift file must have unique name across entire project
   - Xcode treats filenames as flat namespace
   - Bad: `Views/Home/ContentView.swift` + `Views/Profile/ContentView.swift`
   - Good: `HomeContentView.swift` + `ProfileContentView.swift`

2. **Test Target Type**: Use `bundle.unit-test` not `unitTests`

3. **No CocoaPods**: Only SPM dependencies

## Architecture Patterns

### MVVM Example
```swift
// Model
struct Event: Identifiable {
    let id: UUID
    var title: String
    var date: Date
}

// ViewModel
@Observable
class EventsViewModel {
    var events: [Event] = []

    func loadEvents() async {
        // Business logic here
    }
}

// View
struct EventsView: View {
    @State private var viewModel = EventsViewModel()

    var body: some View {
        List(viewModel.events) { event in
            EventRow(event: event)
        }
        .task {
            await viewModel.loadEvents()
        }
    }
}
```

### Glassmorphism UI
```swift
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}
```

## Testing

### XCTest + Snapshot Testing
```swift
import XCTest
import SnapshotTesting
@testable import YourApp

final class EventsViewTests: XCTestCase {
    func testEventsView() {
        let view = EventsView()
        assertSnapshot(matching: view, as: .image)
    }
}
```

## Common Pitfalls

1. ❌ Using @Query in SwiftData (causes crashes)
   ✅ Use @State + modelContext.fetch() instead

2. ❌ Mixing UIKit and SwiftUI unnecessarily
   ✅ Pure SwiftUI for new projects

3. ❌ Not using @Observable (iOS 17+)
   ✅ Replace ObservableObject with @Observable

4. ❌ Hardcoded colors/strings
   ✅ Use SwiftGen for type-safe resources

## Production Checklist

- [ ] SwiftLint configured and passing
- [ ] SwiftGen for assets/strings
- [ ] Unit tests >70% coverage
- [ ] Snapshot tests for key screens
- [ ] Fastlane configured
- [ ] Error handling implemented
- [ ] Accessibility labels added
- [ ] Dark mode supported
- [ ] iPad layout tested
- [ ] Performance profiled (Instruments)

## Activation

When building iOS apps, Claude will automatically use these guidelines if this skill is present in `.claude/skills/`.

