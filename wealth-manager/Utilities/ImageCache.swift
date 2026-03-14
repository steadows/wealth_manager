import Foundation
#if canImport(UIKit)
import UIKit
/// Platform-agnostic image type alias.
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// Platform-agnostic image type alias.
typealias PlatformImage = NSImage
#endif

/// Thread-safe in-memory image cache backed by NSCache.
/// Used for caching institution logos and other remote images.
final class ImageCache: @unchecked Sendable {

    // MARK: - Properties

    private let cache: NSCache<NSString, PlatformImage>

    /// Shared singleton instance for app-wide caching.
    static let shared = ImageCache()

    // MARK: - Init

    /// Creates a new image cache.
    /// - Parameter countLimit: Maximum number of images to cache. 0 means no limit.
    init(countLimit: Int = 100) {
        cache = NSCache<NSString, PlatformImage>()
        cache.countLimit = countLimit
    }

    // MARK: - Public API

    /// Retrieves a cached image for the given key.
    /// - Parameter key: The cache key (typically a URL string).
    /// - Returns: The cached image, or nil if not found.
    func get(forKey key: String) -> PlatformImage? {
        cache.object(forKey: key as NSString)
    }

    /// Stores an image in the cache.
    /// - Parameters:
    ///   - image: The image to cache.
    ///   - key: The cache key (typically a URL string).
    func set(_ image: PlatformImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    /// Removes a cached image for the given key.
    /// - Parameter key: The cache key to remove.
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// Removes all cached images.
    func removeAll() {
        cache.removeAllObjects()
    }
}
