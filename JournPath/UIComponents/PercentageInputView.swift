import SwiftUI

public struct PercentageInputView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var text: String
    
    var limit: Double? = 100.0
    var onDone: (() -> Void)? = nil

    @State private var invalidAttempts: Int = 0
    @State private var localText: String = ""

    // MARK: - Amount display

    private var formattedAmount: String {
        guard !localText.isEmpty else { return "0" }
        return localText
    }

    private var isSaveDisabled: Bool {
        localText.isEmpty || localText == "0" || isOverLimit
    }

    private var isOverLimit: Bool {
        guard let limit = limit, let val = Double(localText) else { return false }
        return val > limit
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Massive Amount Display
                HStack(alignment: .bottom, spacing: 2) {
                    Text(formattedAmount)
                        .font(.system(size: 100, weight: .regular))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        
                    Text("%")
                        .font(.system(size: 40, weight: .regular))
                        .padding(.bottom, 16)
                }
                .foregroundStyle(isOverLimit ? Color.red : .primary)
                .contentTransition(.numericText())
                .shake(trigger: invalidAttempts)
                .padding(.horizontal, 24)

                if let limit = limit {
                    Text("Limit: \(limit.formatted(.number.precision(.fractionLength(0...2))))%")
                        .font(.caption)
                        .foregroundColor(isOverLimit ? .red : .secondary)
                        .padding(.top, 8)
                }

                Spacer()

                // Bottom Area (Numpad)
                VStack(spacing: 0) {
                    Button {
                        if localText.hasSuffix(".") {
                            localText = String(localText.dropLast())
                        }
                        text = localText
                        if let onDone = onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(isSaveDisabled ? Color.primary.opacity(0.3) : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isSaveDisabled ? Color.gray.opacity(0.2) : Color.brand)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .disabled(isSaveDisabled)

                    NumberPad(
                        text: $localText,
                        maxFractionDigits: 0,
                        limit: limit,
                        onError: { invalidAttempts += 1 }
                    )
                    .padding(.bottom, 32)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSaveDisabled)
            .onAppear {
                localText = text
            }
        }
    }
}
