import Foundation
import AppKit
import ImageIO

extension NSImage: @retroactive @unchecked Sendable {}

public final class SagaImageLoader: @unchecked Sendable {
    public static let shared = SagaImageLoader()
    
    private let cache = NSCache<NSURL, NSImage>()
    
    private init() {
        // キャッシュ件数の制限。前後数ページのプリロードを加味し、十分なサイズを確保
        cache.countLimit = 50
    }
    
    public func isCached(url: URL) -> Bool {
        return cache.object(forKey: url as NSURL) != nil
    }
    
    public func clearCache() {
        cache.removeAllObjects()
    }
    
    public func loadImage(at url: URL) async throws -> NSImage {
        // 1. キャッシュがあれば即座に返す
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }
        
        // 2. 非同期でデコードを実行
        return try await Task.detached(priority: .userInitiated) {
            let options: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true
            ]
            
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                throw NSError(domain: "SagaImageLoaderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image source"])
            }
            
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
                throw NSError(domain: "SagaImageLoaderError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from source"])
            }
            
            // CGImageからNSImageを作成
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            let image = NSImage(cgImage: cgImage, size: size)
            
            // キャッシュへ格納
            self.cache.setObject(image, forKey: url as NSURL)
            
            return image
        }.value
    }
}
