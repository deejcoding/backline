//
//  CachedAsyncImage.swift
//  backline
//
//  Created by Khadija Aslam on 4/9/26.
//

import SwiftUI
import Kingfisher

/// Drop-in cached image view powered by Kingfisher.
/// Provides memory + disk caching, downsampled decoding, and fade-in transitions
/// while keeping the same `(Image) -> Content` closure API used throughout the app.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {

    let url: URL?
    let accessibilityDescription: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = true

    init(
        url: URL?,
        accessibilityDescription: String? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.accessibilityDescription = accessibilityDescription
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
        .ifLet(accessibilityDescription) { view, description in
            view
                .accessibilityLabel(description)
                .accessibilityAddTraits(.isImage)
        }
    }

    private func loadImage() async {
        guard let url else {
            isLoading = false
            return
        }

        // Use Kingfisher's cache-aware retrieval (memory + disk)
        do {
            let result = try await KingfisherManager.shared.retrieveImage(with: url)
            self.loadedImage = result.image
        } catch {
            // Failed to load — placeholder stays visible
        }
        isLoading = false
    }
}

// MARK: - Conditional modifier helper

extension View {
    @ViewBuilder
    func ifLet<T, Modified: View>(_ value: T?, transform: (Self, T) -> Modified) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
