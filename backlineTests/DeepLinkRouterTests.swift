//
//  DeepLinkRouterTests.swift
//  backlineTests
//

import Foundation
import Testing
@testable import backline

struct DeepLinkRouterTests {

    private func makeRouter() -> DeepLinkRouter {
        DeepLinkRouter()
    }

    @Test func parsesListingDeepLink() {
        let router = makeRouter()
        router.handle(URL(string: "backline://listing/abc123")!)
        #expect(router.pendingDeepLink == .listing(id: "abc123"))
    }

    @Test func parsesServiceDeepLink() {
        let router = makeRouter()
        router.handle(URL(string: "backline://service/xyz")!)
        #expect(router.pendingDeepLink == .service(id: "xyz"))
    }

    @Test func parsesISODeepLink() {
        let router = makeRouter()
        router.handle(URL(string: "backline://iso/post1")!)
        #expect(router.pendingDeepLink == .iso(id: "post1"))
    }

    @Test func parsesFlyerDeepLink() {
        let router = makeRouter()
        router.handle(URL(string: "backline://flyer/fly1")!)
        #expect(router.pendingDeepLink == .flyer(id: "fly1"))
    }

    @Test func parsesProfileDeepLink() {
        let router = makeRouter()
        router.handle(URL(string: "backline://profile/uid123/username")!)
        #expect(router.pendingDeepLink == .profile(uid: "uid123", username: "username"))
    }

    @Test func handlesURLEncodedUsernames() {
        let router = makeRouter()
        router.handle(URL(string: "backline://profile/uid123/cool%20user")!)
        #expect(router.pendingDeepLink == .profile(uid: "uid123", username: "cool user"))
    }

    @Test func ignoresNonBacklineScheme() {
        let router = makeRouter()
        router.handle(URL(string: "https://example.com/listing/abc")!)
        #expect(router.pendingDeepLink == nil)
    }

    @Test func ignoresUnknownHost() {
        let router = makeRouter()
        router.handle(URL(string: "backline://unknown/123")!)
        #expect(router.pendingDeepLink == nil)
    }

    @Test func handlesMissingPathComponents() {
        let router = makeRouter()
        router.handle(URL(string: "backline://listing")!)
        // No path component, so no deep link should be set
        #expect(router.pendingDeepLink == nil)
    }

    @Test func chatDeepLinkNotHandled() {
        // The switch doesn't have a "chat" case, so it falls through to default
        let router = makeRouter()
        router.handle(URL(string: "backline://chat/conv123")!)
        #expect(router.pendingDeepLink == nil)
    }
}
