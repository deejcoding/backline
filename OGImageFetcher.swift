//
//  OGImageFetcher.swift
//  backline
//
//  Created by Khadija Aslam on 4/28/26.
//

import Foundation

/// Fetches Open Graph image URLs from web pages for automatic thumbnail detection.
enum OGImageFetcher {

    /// Attempts to fetch the `og:image` meta tag content from the given URL string.
    /// Returns the image URL string, or `nil` if not found or on error.
    static func fetchOGImage(from urlString: String) async -> String? {
        guard let url = URL(string: urlString),
              url.scheme?.hasPrefix("http") == true else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        // Some sites block non-browser user agents
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Only parse the first portion of the HTML to find meta tags (they're in <head>)
            let maxBytes = min(data.count, 50_000)
            let subset = data.prefix(maxBytes)

            guard let html = String(data: subset, encoding: .utf8)
                    ?? String(data: subset, encoding: .ascii) else {
                return nil
            }

            return parseOGImage(from: html)
        } catch {
            return nil
        }
    }

    /// Parses HTML to find `<meta property="og:image" content="...">`.
    private static func parseOGImage(from html: String) -> String? {
        // Match meta tags with og:image property — handles various attribute orderings
        // Pattern 1: property before content
        let patterns = [
            #"<meta[^>]+property\s*=\s*["']og:image["'][^>]+content\s*=\s*["']([^"']+)["']"#,
            #"<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]+property\s*=\s*["']og:image["']"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let captureRange = Range(match.range(at: 1), in: html) {
                    let imageURL = String(html[captureRange])
                    if !imageURL.isEmpty {
                        return imageURL
                    }
                }
            }
        }

        return nil
    }
}
