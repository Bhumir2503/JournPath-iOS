import SwiftUI

struct TestView: View {
    @State private var participant: String? = nil
    
    var body: some View {
        Group {
            if let url = participant {
                Text(url)
            } else {
                initialsView
            }
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle().fill(Color.blue)
            Text("AB")
        }
    }
}
