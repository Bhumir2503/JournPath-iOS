import Foundation

enum FilePickerSource: String, Identifiable, CaseIterable {
    case camera, photoLibrary, scanner, files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera:       "Take Photo"
        case .photoLibrary: "Photo Library"
        case .scanner:      "Scan Document"
        case .files:        "Choose File"
        }
    }

    var systemImage: String {
        switch self {
        case .camera:       "camera"
        case .photoLibrary: "photo.on.rectangle"
        case .scanner:      "doc.viewfinder"
        case .files:        "doc"
        }
    }

    /// Only camera and scanner are full-screen presentations. `.files` and
    /// `.photoLibrary` are system modifiers, not sheets.
    var isFullScreen: Bool { self == .camera || self == .scanner }
}