import SwiftUI

public struct PercentageInputView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var text: String
    
    var limit: Double? = 100.0
    var onDone: (() -> Void)? = nil

    @State private var invalidAttempts: Int = 0

    // MARK: - Amount display

    private var formattedAmount: String {
        guard !text.isEmpty else { return "0" }
        return text
    }

    private var isSaveDisabled: Bool {
        text.isEmpty || text == "0" || isOverLimit
    }

    private var isOverLimit: Bool {
        guard let limit = limit, let val = Double(text) else { return false }
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
                        text: $text,
                        maxFractionDigits: 2,
                        limit: limit,
                        onError: { invalidAttempts += 1 }
                    )
                    .padding(.bottom, 32)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSaveDisabled)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}
