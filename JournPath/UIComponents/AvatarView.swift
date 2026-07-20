import SwiftUI
import Kingfisher

struct AvatarView: View {
    let name: String
    let color: Color
    var imageUrl: String? = nil

    var initials: String {
        let words = name.components(separatedBy: .whitespacesAndNewlines)
        let firstLetters = words.compactMap { $0.first }
        return String(firstLetters.prefix(2)).uppercased()
    }

    var fallbackView: some View {
        Text(initials)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(color)
            .clipShape(Circle())
    }

    var body: some View {
        if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
            KFImage(url)
                .placeholder {
                    fallbackView
                }
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            fallbackView
        }
    }
}