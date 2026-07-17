import SwiftUI

extension View {
    /// Presents an alert directly from an optional APIError.
    func alert(error: Binding<APIError?>) -> some View {
        self.alert(
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented { error.wrappedValue = nil }
                }
            ),
            error: error.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {
                error.wrappedValue = nil
            }
        } message: { err in
            Text(err.recoverySuggestion ?? "An unknown error occurred.")
        }
    }
}
