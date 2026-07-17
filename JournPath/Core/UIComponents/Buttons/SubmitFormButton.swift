import SwiftUI
import UIKit

struct SubmitFormButton: View {
    let title: String
    var isDisabled: Bool = false
    var activeColor: Color = .blue
    var loadingTransitionAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    let action: () async throws -> Void

    @State private var isLoading: Bool = false
    @State private var isSuccess: Bool = false
    @State private var shakeTrigger: Int = 0

    init(
        _ title: String,
        isDisabled: Bool = false,
        activeColor: Color = .blue,
        loadingTransitionAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.7),
        action: @escaping () async throws -> Void
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.activeColor = activeColor
        self.loadingTransitionAnimation = loadingTransitionAnimation
        self.action = action
    }

    private var isInteractionDisabled: Bool {
        isLoading || isSuccess || isDisabled
    }

    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            guard !isLoading, !isSuccess else { return }
            
            Task {
                isLoading = true
                do {
                    // Wait for the async action to complete
                    try await action()
                    
                    // On success, show the checkmark
                    isLoading = false
                    isSuccess = true
                    
                    // Reset to idle state after a delay
                    try? await Task.sleep(for: .seconds(1.5))
                    isSuccess = false
                    
                } catch {
                    // On error, stop loading and trigger the shake animation
                    isLoading = false
                    shakeTrigger += 1
                }
            }
        } label: {
            ZStack {
                if isSuccess {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.4).combined(with: .opacity),
                                removal: .scale(scale: 0.4).combined(with: .opacity)
                            )
                        )
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.4).combined(with: .opacity),
                                removal: .scale(scale: 0.4).combined(with: .opacity)
                            )
                        )
                } else {
                    Text(title)
                        .bold()
                        .foregroundColor(.white)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())  // Makes the whole row tappable
        }
        .disabled(isInteractionDisabled)
        .listRowBackground(
            isInteractionDisabled && !isLoading && !isSuccess
                ? Color.gray.opacity(0.3)
                : activeColor
        )
        .shake(trigger: shakeTrigger)
        .animation(loadingTransitionAnimation, value: isLoading)
        .animation(loadingTransitionAnimation, value: isSuccess)
        .onChange(of: isSuccess) { _, newValue in
            if newValue {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    Form {
        Section {
//            SubmitFormButton("Sign In", isDisabled: false) {
//                try? await Task.sleep(for: .seconds(1))
//            }
            
//            SubmitFormButton("Disabled", isDisabled: true) { }
//            
            SubmitFormButton("Simulate Error", activeColor: .red) {
                try? await Task.sleep(for: .seconds(1))
                throw URLError(.badServerResponse)
            }
        }
    }
}
