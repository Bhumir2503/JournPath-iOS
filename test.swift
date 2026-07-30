import SwiftUI

struct TestView: View {
    @State var item: String?
    var body: some View {
        Text("Test")
            .confirmationDialog("Confirm", isPresented: Binding(
                get: { item != nil },
                set: { if !$0 { item = nil } }
            ), presenting: item) { data in
                Button("OK") {}
            }
    }
}
