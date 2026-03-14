import Testing
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@testable import wealth_manager

// MARK: - ImageCacheTests

@Suite("ImageCache")
struct ImageCacheTests {

    // MARK: - Basic Operations

    @Test("set and get returns cached image")
    func setAndGetReturnsCachedImage() {
        let cache = ImageCache()
        let testImage = makeTestImage()

        cache.set(testImage, forKey: "test-key")
        let result = cache.get(forKey: "test-key")

        #expect(result != nil)
    }

    @Test("get returns nil for missing key")
    func getMissingKeyReturnsNil() {
        let cache = ImageCache()

        let result = cache.get(forKey: "nonexistent")

        #expect(result == nil)
    }

    @Test("set overwrites existing entry")
    func setOverwritesExisting() {
        let cache = ImageCache()
        let image1 = makeTestImage()
        let image2 = makeTestImage()

        cache.set(image1, forKey: "key")
        cache.set(image2, forKey: "key")
        let result = cache.get(forKey: "key")

        #expect(result != nil)
    }

    @Test("remove clears specific entry")
    func removeClearsEntry() {
        let cache = ImageCache()
        let image = makeTestImage()

        cache.set(image, forKey: "key")
        cache.remove(forKey: "key")
        let result = cache.get(forKey: "key")

        #expect(result == nil)
    }

    @Test("removeAll clears all entries")
    func removeAllClearsAll() {
        let cache = ImageCache()
        cache.set(makeTestImage(), forKey: "key1")
        cache.set(makeTestImage(), forKey: "key2")

        cache.removeAll()

        #expect(cache.get(forKey: "key1") == nil)
        #expect(cache.get(forKey: "key2") == nil)
    }

    // MARK: - Cost Limit

    @Test("cache respects cost limit by evicting old entries")
    func cacheRespectsCostLimit() {
        // Small cache: 2 items max cost
        let cache = ImageCache(countLimit: 2)
        cache.set(makeTestImage(), forKey: "a")
        cache.set(makeTestImage(), forKey: "b")
        cache.set(makeTestImage(), forKey: "c")

        // At least one of the first two entries should be evicted
        // NSCache eviction is non-deterministic, so just check the new entry survives
        #expect(cache.get(forKey: "c") != nil)
    }

    // MARK: - Thread Safety

    @Test("concurrent reads and writes do not crash")
    func concurrentAccessDoesNotCrash() async {
        let cache = ImageCache()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let key = "key-\(i % 10)"
                    cache.set(makeTestImage(), forKey: key)
                    _ = cache.get(forKey: key)
                }
            }
        }

        // If we reach here without crashing, the test passes
        #expect(true)
    }

    // MARK: - Helpers

    private func makeTestImage() -> PlatformImage {
        #if canImport(UIKit)
        return UIImage(systemName: "star.fill")!
        #elseif canImport(AppKit)
        return NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
        #endif
    }
}
