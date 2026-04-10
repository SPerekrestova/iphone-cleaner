import UIKit

@Observable
final class ImageCacheService {
    static let shared = ImageCacheService()
    
    // Internal cache
    private let cache: NSCache<NSString, UIImage>
    
    init() {
        cache = NSCache<NSString, UIImage>()
        // Set a reasonable limit of memory items (e.g., 50 heavy images)
        cache.countLimit = 50
    }
    
    func image(for id: String) -> UIImage? {
        return cache.object(forKey: id as NSString)
    }
    
    func setImage(_ image: UIImage, for id: String) {
        cache.setObject(image, forKey: id as NSString)
    }
    
    func removeImage(for id: String) {
        cache.removeObject(forKey: id as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}
