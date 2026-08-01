import SwiftUI

struct StorageQuotaBar: View {

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("0 MB / 10 MB")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(
                value: 0,
                total: 100
            )
            .progressViewStyle(.linear)
            .tint(.accentColor)
            
        }
    }
}