//
//  CachedAsyncImage.swift
//  InstaGridswift
//

import SwiftUI

/// A cached image view that loads from local URLs with thumbnail support.
/// Uses ImageCache for in-memory caching and generates thumbnails on first load.
struct CachedAsyncImage: View {
    let url: URL?
    let cacheKey: String
    let useThumbnail: Bool

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    init(url: URL?, cacheKey: String, useThumbnail: Bool = true) {
        self.url = url
        self.cacheKey = cacheKey
        self.useThumbnail = useThumbnail
    }

    var body: some View {
        ZStack {
            // Base layer - placeholder or error state
            if loadFailed {
                Color.gridItemPlaceholder
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
            } else if loadedImage == nil {
                // Loading placeholder with subtle animation
                Color.gridItemPlaceholder
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    .onAppear { loadImage() }
            }

            // Loaded image with fade-in transition
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            }
        }
        .animation(.easeIn(duration: 0.2), value: loadedImage != nil)
    }

    private func loadImage() {
        // Check cache first
        if useThumbnail, let cached = ImageCache.shared.thumbnail(for: cacheKey) {
            loadedImage = cached
            return
        }
        if !useThumbnail, let cached = ImageCache.shared.fullImage(for: cacheKey) {
            loadedImage = cached
            return
        }

        guard !isLoading, let url = url else {
            loadFailed = url == nil
            return
        }

        isLoading = true

        Task {
            do {
                let data = try Data(contentsOf: url)
                guard let uiImage = UIImage(data: data) else {
                    await MainActor.run {
                        loadFailed = true
                        isLoading = false
                    }
                    return
                }

                if useThumbnail {
                    let thumbnail = await ImageCache.generateThumbnail(from: uiImage)
                    ImageCache.shared.setThumbnail(thumbnail, for: cacheKey)
                    await MainActor.run {
                        loadedImage = thumbnail
                        isLoading = false
                    }
                } else {
                    ImageCache.shared.setFullImage(uiImage, for: cacheKey)
                    await MainActor.run {
                        loadedImage = uiImage
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    loadFailed = true
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    CachedAsyncImage(
        url: nil,
        cacheKey: "test"
    )
    .frame(width: 100, height: 100)
}
