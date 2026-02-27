import AVFoundation
import Photos
import UIKit

final class PhotoLibraryService {
    enum AuthError: Error {
        case denied
        case restricted
    }

    func requestAuthorization() async throws -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return status
        case .denied:
            throw AuthError.denied
        case .restricted:
            throw AuthError.restricted
        default:
            throw AuthError.denied
        }
    }

    func fetchAllPhotos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func loadImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func loadImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    func deleteAssets(_ assetIds: [String]) async throws {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIds,
            options: nil
        )
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }

    func getAssetFileSize(_ asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first,
              let size = resource.value(forKey: "fileSize") as? Int64 else {
            return 0
        }
        return size
    }

    // MARK: - Video Support

    func fetchAllMedia() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    static func isScreenRecording(subtypeRawValue: UInt) -> Bool {
        return subtypeRawValue & 524288 != 0
    }

    func loadImageWithTimeout(
        forAssetId assetId: String,
        targetSize: CGSize,
        timeout: Duration = .seconds(5)
    ) async -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        return await loadImageWithTimeout(for: asset, targetSize: targetSize, timeout: timeout)
    }

    func loadImageWithTimeout(
        for asset: PHAsset,
        targetSize: CGSize,
        timeout: Duration = .seconds(5)
    ) async -> UIImage? {
        await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                await self.loadImage(for: asset, targetSize: targetSize)
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    func extractKeyframes(from asset: PHAsset, count: Int = 8) async -> [CGImage] {
        guard asset.mediaType == .video else { return [] }

        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let avAsset else {
                    continuation.resume(returning: [])
                    return
                }

                let generator = AVAssetImageGenerator(asset: avAsset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = .zero
                generator.requestedTimeToleranceAfter = .zero

                let duration = avAsset.duration.seconds
                guard duration > 0 else {
                    continuation.resume(returning: [])
                    return
                }

                let interval = duration / Double(count)
                var images: [CGImage] = []

                for i in 0..<count {
                    let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
                    if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                        images.append(image)
                    }
                }

                continuation.resume(returning: images)
            }
        }
    }
}
