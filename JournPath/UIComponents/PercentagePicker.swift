import SwiftUI

/// Whole-percent entry, by design: `maxFractionDigits: 0` below is a product
/// decision, not an accident. Fractional splits (33.33%) are served by the
/// Manually and Evenly modes instead — matching what the keypad can enter and
/// what reopening can redisplay, so no value ever changes just by viewing it.
/// If fractional percentages are ever wanted, change `maxFractionDigits` to 2
/// and swap the reopen formatting for the trailing-zero trim in
/// `CurrencyInfo.editingString` — and update the Cloud Function's validator
/// to accept non-whole basis points at the same time.
struct PercentagePicker: View {
    @Binding var percentage: Double?
    var limit: Double? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var pctString: String = ""
    @State private var shakeAttempts: Int = 0

    /// The limit already excludes this participant's own current percentage
    /// (see `availablePercentage(excluding:)`), so it is the true ceiling for
    /// what can be entered here.
    private var effectiveMax: Double {
        min(limit ?? 100, 100)
    }

    private var limitExhausted: Bool {
        effectiveMax <= 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Percentage display
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(pctString.isEmpty ? "0" : pctString)
                            .font(.system(size: 64, weight: .semibold, design: .rounded))
                            .foregroundStyle(pctString.isEmpty ? Color(UIColor.tertiaryLabel) : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Text("%")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundStyle(pctString.isEmpty ? Color(UIColor.tertiaryLabel) : .primary)
                    }

                    if limitExhausted {
                        // A dead keypad with no explanation reads as a bug.
                        // Say why nothing can be entered and how to fix it.
                        Text("100% is already assigned — lower someone else's share first")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    } else if let limit {
                        Text("Max: \(String(format: "%.0f", min(limit, 100)))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .modifier(Shake(animatableData: CGFloat(shakeAttempts)))
                .animation(.default, value: shakeAttempts)

                Spacer()

                // Keypad
                CustomNumberPad(
                    text: $pctString,
                    maxFractionDigits: 0,
                    maxAmount: effectiveMax
                ) {
                    withAnimation(.default) {
                        shakeAttempts += 1
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Percentage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmAndDismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Mirror AmountPicker: only populate for a meaningful value, so a
            // cleared/zero state always opens as the empty placeholder.
            if let p = percentage, p > 0 {
                pctString = String(format: "%.0f", p)
            }
        }
    }

    // MARK: - Actions

    private func confirmAndDismiss() {
        // Zero and empty both mean "no share" — never store 0.0. This keeps
        // the picker's contract identical to AmountPicker and independent of
        // the caller's binding sanitizing it.
        if let val = Double(pctString), val > 0 {
            percentage = val
        } else {
            percentage = nil
        }
        dismiss()
    }
}
