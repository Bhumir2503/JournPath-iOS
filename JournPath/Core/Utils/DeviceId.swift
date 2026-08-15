import Foundation
import UIKit

enum DeviceID {
    private static let key = "app.deviceId"

    /// Stable per install. `identifierForVendor` resets on reinstall, which
    /// matches FileUploadCache's lifetime — a reinstall has no staged bytes.
    static let current: String = {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }()
}
