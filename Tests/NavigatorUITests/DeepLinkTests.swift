import SwiftUI
import Testing
import UIKit
@testable import NavigatorUI

@MainActor
struct DeepLinkTests {
    private typealias Link = LinkRoute

    private func makeRouter() -> DeepLinkRouter {
        let links = DeepLinkRouter()
        links.register("profile/:id") { [.push(Link.profile($0["id"] ?? ""))] }
        links.register("profile/:id/settings") { match in
            [.push(Link.profile(match["id"] ?? "")), .push(Link.settings)]
        }
        links.register("details/:id") { match in match.int("id").map { [.push(TestRoute.detail($0))] } }
        links.register("editor") { _ in [.present(ModalRoute.editor), .push(TestRoute.settings)] }
        return links
    }

    @Test(arguments: [
        "myapp://profile/123",
        "myapp:///profile/123",
        "myapp://Profile/123?ref=x",
        "https://example.com/profile/123"
    ])
    func hostAndPathBothResolve(_ string: String) {
        let steps = makeRouter().steps(for: URL(string: string)!)
        #expect(steps?.count == 1)
        #expect(steps?.first?.route == AnyRoute(Link.profile("123")))
    }

    @Test func handlerCanRejectAndQueryIsExposed() {
        let links = makeRouter()
        #expect(links.steps(for: URL(string: "myapp://details/abc")!) == nil)
        #expect(links.steps(for: URL(string: "myapp://details/7")!)?.first?.route == AnyRoute(TestRoute.detail(7)))
        #expect(links.steps(for: URL(string: "myapp://unknown")!) == nil)

        var captured: DeepLinkMatch?
        links.register("search") { captured = $0; return [.push(TestRoute.settings)] }
        _ = links.steps(for: URL(string: "myapp://search?q=swift&page=2")!)
        #expect(captured?["q"] == "swift")
        #expect(captured?.int("page") == 2)
    }

    @Test(.requiresScene) func replaceStackBuildsMultiScreenStackFromAnyState() async {
        let harness = Harness.make(deepLinks: makeRouter())
        await harness.settle()
        harness.navigator.push(TestRoute.detail(1), animated: false)
        harness.navigator.present(ModalRoute.editor, animated: false)
        await harness.settle()

        let handled = harness.navigator.open(URL(string: "myapp://profile/42/settings")!)
        await harness.settle()

        #expect(handled)
        #expect(harness.controller.presentedViewController == nil)
        #expect(harness.navigator.routes == [
            AnyRoute(TestRoute.home), AnyRoute(Link.profile("42")), AnyRoute(Link.settings)
        ])
    }

    @Test(.requiresScene) func stepsAfterAPresentationApplyInsideTheModal() async {
        let harness = Harness.make(deepLinks: makeRouter())
        await harness.settle()

        harness.navigator.open(URL(string: "myapp://editor")!)
        await harness.settle()

        #expect(harness.navigator.routes == [AnyRoute(TestRoute.home)])
        #expect(harness.visibleStack == [AnyRoute(ModalRoute.editor), AnyRoute(TestRoute.settings)])
    }

    @Test func unmatchedURLLeavesStateAndReports() async {
        let harness = Harness.make(deepLinks: makeRouter())
        await harness.settle()
        harness.navigator.push(TestRoute.settings, animated: false)

        let handled = harness.navigator.open(URL(string: "myapp://nope")!)

        #expect(!handled)
        #expect(harness.navigator.depth == 2)
        #expect(harness.events.contains { if case .deepLink(_, handled: false) = $0 { true } else { false } })
    }

    @Test func appendStrategyKeepsCurrentScreens() async {
        let links = makeRouter()
        links.strategy = .append
        let harness = Harness.make(deepLinks: links)
        await harness.settle()
        harness.navigator.push(TestRoute.detail(1), animated: false)

        harness.navigator.open(URL(string: "myapp://profile/9")!)
        await harness.settle()

        #expect(harness.navigator.routes.count == 3)
        #expect(harness.navigator.routes.last == AnyRoute(Link.profile("9")))
    }
}
