//
//  DeepLinkRouter.swift
//  backline
//
//  Created by Khadija Aslam on 5/6/26.
//

import SwiftUI

// MARK: - Deep Link Types

enum DeepLink: Equatable {
    case listing(id: String)
    case service(id: String)
    case iso(id: String)
    case flyer(id: String)
    case profile(uid: String, username: String)
    case chat(conversationId: String)
}

// MARK: - Router

@Observable
class DeepLinkRouter {

    var pendingDeepLink: DeepLink?

    /// Parses a `backline://` URL and sets the pending deep link.
    func handle(_ url: URL) {
        guard url.scheme == "backline" else { return }

        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "listing":
            if let id = pathComponents.first {
                pendingDeepLink = .listing(id: id)
            }
        case "service":
            if let id = pathComponents.first {
                pendingDeepLink = .service(id: id)
            }
        case "iso":
            if let id = pathComponents.first {
                pendingDeepLink = .iso(id: id)
            }
        case "flyer":
            if let id = pathComponents.first {
                pendingDeepLink = .flyer(id: id)
            }
        case "profile":
            if pathComponents.count >= 2 {
                let uid = pathComponents[0]
                let username = pathComponents[1].removingPercentEncoding ?? pathComponents[1]
                pendingDeepLink = .profile(uid: uid, username: username)
            }
        default:
            break
        }
    }
}
