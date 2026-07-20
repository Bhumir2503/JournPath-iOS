import SwiftUI

extension View {
    func alert(error: Binding<AnyAppError?>) -> some View {
        self.alert(
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            error: error.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: { err in
            Text(err.recoverySuggestion ?? "An unknown error occurred.")
        }
    }
}