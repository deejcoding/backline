//
//  CachedAsyncImage.swift
//  backline
//
//  Created by Khadija Aslam on 4/9/26.
//

import SwiftUI

/// A simple in-memory image cache shared across the app.
final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func get(_ url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func set(_ url: String, image: UIImage) {
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: url as NSString, cost: cost)
    }
}

/// Drop-in replacement for AsyncImage that caches downloaded images in memory.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {

    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            isLoading = false
            return
        }

        let urlString = url.absoluteString

        // Check cache first
        if let cached = ImageCache.shared.get(urlString) {
            self.uiImage = cached
            self.isLoading = false
            return
        }

        // Download
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ImageCache.shared.set(urlString, image: image)
                self.uiImage = image
            }
        } catch {
            // Failed to load
        }

        isLoading = false
    }
}
