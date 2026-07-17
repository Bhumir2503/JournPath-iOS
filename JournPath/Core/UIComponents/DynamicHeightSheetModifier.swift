import SwiftUI

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct DynamicHeightSheetModifier: ViewModifier {
    @State private var sheetHeight: CGFloat = .zero
    
    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(SizePreferenceKey.self) { newHeight in
                // Only update if the new height is valid and has changed significantly
                // to avoid infinite update loops
                if newHeight > 0 && abs(sheetHeight - newHeight) > 1.0 {
                    sheetHeight = newHeight
                }
            }
            // Use .medium as a fallback while measuring
            .presentationDetents(sheetHeight == .zero ? [.medium] : [.height(sheetHeight)])
    }
}

public extension View {
    /// Applies a dynamic presentation detent that automatically adjusts to the intrinsic height of the view.
    /// Note: This works best with intrinsically sized views like VStack. 
    /// Greedy views like Form, List, or ScrollView may need to be wrapped in a VStack or have fixed size applied.
    func dynamicSheetHeight() -> some View {
        self.modifier(DynamicHeightSheetModifier())
    }
}
