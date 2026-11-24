import NavigatorUI
import SwiftUI

struct HomeView: View {
    @Environment(\.navigator) private var navigator
    @EnvironmentObject private var log: EventLog

    var body: some View {
        List {
            Section("Push") {
                Button("Profile 42") { navigator.push(AppRoute.profile(id: "42")) }
                Button("Settings (fade transition)") {
                    navigator.push(AppRoute.settings, transition: .fade)
                }
                Button("Details, then Settings in one stack change") {
                    navigator.setStack([AppRoute.details(id: 7), AppRoute.settings])
                }
                Button("Editor (pushed, guarded back)") { navigator.push(AppRoute.editor) }
            }
            Section("Modals") {
                Button("Editor (sheet, medium + large)") {
                    navigator.present(AppRoute.editor, style: .sheet(detents: [.medium, .large], showsGrabber: true))
                }
                Button("Filters (sheet)") { navigator.present(AppRoute.filters) }
                Button("Onboarding (full screen)") {
                    navigator.present(AppRoute.onboarding, style: .fullScreen())
                }
            }
            Section("Deep links") {
                Button("Open navigatorui://profile/42/settings") {
                    navigator.open(URL(string: "navigatorui://profile/42/settings")!)
                }
                Button("Open navigatorui://editor/profile/9") {
                    navigator.open(URL(string: "navigatorui://editor/profile/9")!)
                }
            }
            Section("Events") {
                ForEach(Array(log.lines.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("NavigatorUI")
    }
}

struct ProfileView: View {
    @Environment(\.navigator) private var navigator
    let id: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Profile \(id)").font(.title)
            Text("Stack depth: \(navigator.depth)")
            Button("Push Settings") { navigator.push(AppRoute.settings) }
            Button("Pop to root") { navigator.popToRoot() }
            Button("Edit (sheet)") { navigator.present(AppRoute.editor) }
        }
        .navigationTitle("Profile")
    }
}

struct SettingsView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings").font(.title)
            Button("Push Details 777") { navigator.push(AppRoute.details(id: 777)) }
            Button("Back to Profile (if any)") { navigator.pop(to: AppRoute.profile(id: "42")) }
        }
        .navigationTitle("Settings")
    }
}

struct DetailsView: View {
    @Environment(\.navigator) private var navigator
    let id: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("Details \(id)").font(.title)
            Button("Filters (sheet)") { navigator.present(AppRoute.filters) }
            Button("Pop to root") { navigator.popToRoot() }
        }
        .navigationTitle("Details")
    }
}

@MainActor
final class EditorModel: ObservableObject {
    @Published var hasUnsavedChanges = false
    @Published var confirmingDiscard = false
}

/// Shows a pop guard: with unsaved changes, back button and swipe-back ask first.
struct EditorView: View {
    @Environment(\.navigator) private var navigator
    @StateObject private var model = EditorModel()

    var body: some View {
        let model = model
        VStack(spacing: 16) {
            Text("Editor").font(.title)
            Toggle("Unsaved changes", isOn: $model.hasUnsavedChanges).padding(.horizontal)
            Button("Push Profile inside this sheet") { navigator.push(AppRoute.profile(id: "in-sheet")) }
            Button("Close sheet") { navigator.dismissModal() }
            Button("Close everything") { navigator.dismissAll() }
        }
        .navigationTitle("Editor")
        .popGuard {
            if model.hasUnsavedChanges { model.confirmingDiscard = true }
            return !model.hasUnsavedChanges
        }
        .alert("Discard changes?", isPresented: $model.confirmingDiscard) {
            Button("Discard", role: .destructive) {
                model.hasUnsavedChanges = false
                navigator.dismiss(force: true)
            }
            Button("Keep editing", role: .cancel) {}
        }
    }
}

struct FiltersView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        VStack(spacing: 16) {
            Text("Filters").font(.title)
            Button("Done") { navigator.dismiss() }
        }
        .navigationTitle("Filters")
    }
}

struct OnboardingView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome").font(.largeTitle)
            Button("Push Settings in this cover") { navigator.push(AppRoute.settings) }
            Button("Close") { navigator.dismiss() }
        }
        .navigationTitle("Onboarding")
    }
}
