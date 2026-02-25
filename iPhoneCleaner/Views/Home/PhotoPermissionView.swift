import SwiftUI
import Photos

struct PhotoPermissionView: View {
    let onGranted: () -> Void

    @State private var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.purple)

            Text("Photo Access Required")
                .font(.title2.bold())

            Text("iPhone Cleaner needs access to your photo library to find duplicates, blurry photos, and screenshots.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            if status == .denied || status == .restricted {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            } else {
                Button("Allow Access") {
                    Task {
                        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                        status = newStatus
                        if newStatus == .authorized || newStatus == .limited {
                            onGranted()
                        }
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
        }
    }
}
