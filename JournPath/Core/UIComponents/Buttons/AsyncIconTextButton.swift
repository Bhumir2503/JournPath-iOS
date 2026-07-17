import SwiftUI
import UIKit

struct AsyncIconTextButton: View {
    let title: String
    var iconName: String? = nil
    var isSFSymbol: Bool = true
    var isDisabled: Bool = false
    var textColor: Color? = nil
    var buttonColor: Color? = nil
    var successColor: Color? = nil
    var successIconName: String = "checkmark"
    var isFormStyle: Bool = false
    var sleepDuration: Double = 1.5
    var loadingTransitionAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    var resetAfter: Bool = false

    let action: () async throws -> Void
    var closingAction: (() async throws -> Void)? = nil

    @State private var isLoading: Bool = false
    @State private var isSuccess: Bool = false
    @State private var shakeTrigger: Int = 0

    var body: some View {
        IconTextButton(
            title: title,
            iconName: iconName,
            isSFSymbol: isSFSymbol,
            isLoading: isLoading,
            isSuccess: isSuccess,
            isDisabled: isDisabled,
            textColor: textColor,
            buttonColor: buttonColor,
            successColor: successColor,
            successIconName: successIconName,
            isFormStyle: isFormStyle,
            loadingTransitionAnimation: loadingTransitionAnimation
        ) {
            guard !isLoading, !isSuccess else { return }

            Task {
                isLoading = true
                do {
                    // Wait for the async action to complete
                    try await action()

                    // On success, show the checkmark
                    isLoading = false
                    isSuccess = true

                    // Wait to keep checkmark displayed
                    try? await Task.sleep(for: .seconds(sleepDuration))

                    // if resetFlag is true, reset button to initial state
                    if resetAfter {
                        isSuccess = false
                    }

                    try? await closingAction?()

                } catch {
                    // On error, stop loading and trigger the shake animation
                    isLoading = false
                    shakeTrigger += 1
                }
            }
        }
        .shake(trigger: shakeTrigger)
    }
}

// MARK: - Previews

#Preview("Standard Usage") {
    @Previewable @State var showsheet: Bool = false

    VStack(spacing: 16) {
        AsyncIconTextButton(
            title: "Simulate Success",
            iconName: "",
            buttonColor: .red,
            successColor: .blue,
            resetAfter: true,
            action: {
                try? await Task.sleep(for: .seconds(5))
            },
            closingAction: {
                showsheet = true
            }
        )

        AsyncIconTextButton(
            title: "Simulate Failure",
            iconName: "exclamationmark.triangle.fill",
            buttonColor: .red
        ) {
            try? await Task.sleep(for: .seconds(1))
            throw URLError(.badServerResponse)
        }
    }
    .padding()
    .sheet(isPresented: $showsheet) {
        Text("Success Action Completed!")
            .font(.headline)
            .presentationDetents([.medium])
    }
}

#Preview("Form Usage") {
    Form {
        AsyncIconTextButton(
            title: "Submit Form",
            iconName: "paperplane.fill",
            buttonColor: .blue,
            isFormStyle: true,
            resetAfter: true
        ) {
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
