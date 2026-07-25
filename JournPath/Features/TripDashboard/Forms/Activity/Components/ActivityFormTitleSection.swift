import SwiftUI
import MapKit

extension ActivityFormView {
    @ViewBuilder
    var titleSection: some View {
        VStack(spacing: 0) {
            TextField(vm.place.name ?? "Unknown", text: titleBinding)
                .font(.headline)
                .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
