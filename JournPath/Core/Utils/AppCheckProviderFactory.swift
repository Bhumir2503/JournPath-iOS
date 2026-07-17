import FirebaseAppCheck
import FirebaseCore
import Foundation
import SwiftUI

class YourSimpleAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}