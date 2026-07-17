//
//  ShakeEffect.swift
//  MyJourney
//
//  Created by Bhumir Patel on 7/3/26.
//

import Foundation
import SwiftUI


// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 8
    var numberOfShakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travelDistance * sin(animatableData * .pi * numberOfShakes)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

extension View {
    func shake(trigger: Int) -> some View {
        modifier(ShakeViewModifier(trigger: trigger))
    }
}

private struct ShakeViewModifier: ViewModifier {
    let trigger: Int
    @State private var animatableData: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: animatableData))
            .onChange(of: trigger) {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.error)

                animatableData = 0
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatableData = 1
                }
            }
    }
}
