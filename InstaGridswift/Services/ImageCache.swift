//
//  ImageCache.swift
//  InstaGridswift
//

import UIKit

/// A singleton image cache using NSCache for efficient memory management.
/// Automatically evicts images under memory pressure.
final class ImageCache {
    static let shared = ImageCache()

    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fullImageCache = NSCache<NSString, UIImage>()

    private init() {
        // Configure cache limits
        thumbnailCache.countLimit = 200
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024  // 50MB

        fullImageCache.countLimit = 20
        fullImageCache.totalCostLimit = 100 * 1024 * 1024  // 100MB
    }

    // MARK: - Thumbnail Cache

    func thumbnail(for key: String) -> UIImage? {
        thumbnailCache.object(forKey: key as NSString)
    }

    func setThumbnail(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        thumbnailCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    // MARK: - Full Image Cache

    func fullImage(for key: String) -> UIImage? {
        fullImageCache.object(forKey: key as NSString)
    }

    func setFullImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        fullImageCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    // MARK: - Cache Management

    func removeImage(for key: String) {
        thumbnailCache.removeObject(forKey: key as NSString)
        fullImageCache.removeObject(forKey: key as NSString)
    }

    func clearAll() {
        thumbnailCache.removeAllObjects()
        fullImageCache.removeAllObjects()
    }

    // MARK: - Thumbnail Generation

    /// Generates a thumbnail from an image asynchronously
    static func generateThumbnail(from image: UIImage, maxDimension: CGFloat = 400) async -> UIImage {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
                let newSize = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )

                let renderer = UIGraphicsImageRenderer(size: newSize)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
                continuation.resume(returning: thumbnail)
            }
        }
    }
}
