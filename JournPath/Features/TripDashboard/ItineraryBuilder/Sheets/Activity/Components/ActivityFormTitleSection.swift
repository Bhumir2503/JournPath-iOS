import SwiftUI

extension ActivityFormView {
    @ViewBuilder
    var titleSection: some View {
        VStack(spacing: 0) {
            TextField(vm.place.title, text: titleBinding)
                .font(.headline)
                .padding()
                .onChange(of: vm.item.activity?.title ?? "") { _, newValue in
                    if newValue.count > 50 {
                        vm.item.activity?.title = String(newValue.prefix(50))
                    }
                }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
