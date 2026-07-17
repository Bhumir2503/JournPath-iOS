import SwiftUI

struct DynamicSheet<Content: View>: View {
    var animation: Animation
    @ViewBuilder var content: Content
    @State private var sheetHeight: CGFloat = .zero
    var body: some View {
        ZStack {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: { newValue in
                    if sheetHeight == .zero {
                        sheetHeight = min(newValue.height, maxSheetHeight)
                    } else {
                        withAnimation(animation) {
                            sheetHeight = min(newValue.height, maxSheetHeight)
                        }
                    }
                }
        }.modifier(SheetHeightModifier(sheetHeight: sheetHeight))
    }

    var maxSheetHeight: CGFloat {
        windowSize.height - safeAreaTop
    }

    var windowSize: CGSize {
        if let size = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size {
            return size
        }
        return .zero
    }

    var safeAreaTop: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        {
            return window.safeAreaInsets.top
        }
        return 0
    }
}

private struct SheetHeightModifier: ViewModifier, Animatable {
    var sheetHeight: CGFloat
    var animatableData: CGFloat {
        get { sheetHeight }
        set { sheetHeight = newValue }
    }
    func body(content: Content) -> some View {
        content
            .presentationDetents(sheetHeight == .zero ? [.medium] : [.height(sheetHeight)])
    }
}
