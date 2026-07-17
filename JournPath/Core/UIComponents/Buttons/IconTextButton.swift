import SwiftUI
import UIKit

struct IconTextButton: View {
    let title: String
    var iconName: String? = nil
    var isSFSymbol: Bool = true
    var isLoading: Bool = false
    var isSuccess: Bool = false
    var isDisabled: Bool = false
    var textColor: Color? = nil
    var buttonColor: Color? = nil
    var successColor: Color? = nil
    var successIconName: String = "checkmark"
    var isFormStyle: Bool = false
    var loadingTransitionAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    let action: () -> Void

    private var isInteractionDisabled: Bool {
        isLoading || isSuccess || isDisabled
    }

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        } label: {
            ZStack {
                if isSuccess {
                    Image(systemName: successIconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(successColor ?? textColor ?? (buttonColor != nil ? .white : .primary))
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.4).combined(with: .opacity),
                                removal: .scale(scale: 0.4).combined(with: .opacity)
                            )
                        )
                        
                        
                } else if isLoading {
                    ProgressView()
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.4).combined(with: .opacity),
                                removal: .scale(scale: 0.4).combined(with: .opacity)
                            )
                        )
                } else {
                    HStack(spacing: 8) {
                        if let icon = iconName {
                            if isSFSymbol {
                                Image(systemName: icon)
                                    .font(.system(size: 16, weight: .medium))
                            } else {
                                Image(icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            }
                        }
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        )
                    )
            
                }
            }
            .animation(loadingTransitionAnimation, value: isLoading)
            .animation(loadingTransitionAnimation, value: isSuccess)
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: isFormStyle ? nil : 36)
            .contentShape(Rectangle())
        }
        .disabled(isInteractionDisabled)
        .opacity(isDisabled && !isLoading && !isSuccess && !isFormStyle ? 1.0 : 1.0)
        .tint(buttonColor)
        .modifier(IconTextButtonStyleModifier(isProminent: buttonColor != nil, isFormStyle: isFormStyle))
        .scaleEffect(isLoading ? 0.97 : 1.0)
        .animation(loadingTransitionAnimation, value: isLoading)
        .onChange(of: isSuccess) { _, newValue in
            if newValue {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            }
        }
    }
}

private struct IconTextButtonStyleModifier: ViewModifier {
    let isProminent: Bool
    let isFormStyle: Bool

    func body(content: Content) -> some View {
        Group {
            if isFormStyle || isProminent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var isLoading: Bool = false
    VStack(spacing: 16) {
        IconTextButton(title: "Continue with Apple", iconName: "applelogo") {}
        IconTextButton(title: "Custom Text Color", iconName: "applelogo", textColor: .green) {}
        IconTextButton(title: "Custom Button Color", iconName: "star.fill", buttonColor: .blue) { isLoading = false }
        IconTextButton(title: "Loading...", iconName: "star.fill", isLoading: isLoading, buttonColor: .red) { isLoading = !isLoading }
        IconTextButton(title: "Disabled", iconName: "lock.fill", isDisabled: true, buttonColor: .blue) {}
        
        Button("Toggle Disabled State") {
            isLoading.toggle()
        }.buttonStyle(.borderedProminent).disabled(true)
    }
    .padding()
}

#Preview("Failed Action (Shake)") {
    @Previewable @State var isLoading: Bool = false
    @Previewable @State var shakeTrigger: Int = 0

    VStack(spacing: 16) {
        Text("Tap to simulate a failed submission")
            .font(.footnote)
            .foregroundColor(.secondary)

        IconTextButton(
            title: "Submit",
            iconName: "paperplane.fill",
            isLoading: isLoading,
            buttonColor: .red
        ) {
            guard !isLoading else { return }
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isLoading = false
                shakeTrigger += 1
            }
        }
        .shake(trigger: shakeTrigger)
    }
    .padding()
}

#Preview("Successful Action (Checkmark)") {
    @Previewable @State var isLoading: Bool = false
    @Previewable @State var isSuccess: Bool = false

    VStack(spacing: 16) {
        Text("Tap to simulate a successful submission")
            .font(.footnote)
            .foregroundColor(.secondary)

        IconTextButton(
            title: "Submit",
            iconName: "paperplane.fill",
            isLoading: isLoading,
            isSuccess: isSuccess,
            buttonColor: .green,
            successColor: .green
        ) {
            guard !isLoading, !isSuccess else { return }
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isLoading = false
                isSuccess = true
                // Reset back to idle after showing the checkmark for a moment.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    isSuccess = false
                }
            }
        }
    }
    .padding()
}

#Preview("Form Usage") {
    Form {
        IconTextButton(title: "Sign In", iconName: "person.circle", isFormStyle: true) {}
        IconTextButton(title: "Simulate Error", iconName: "xmark.circle", buttonColor: .red, isFormStyle: true) {}
    }
}
