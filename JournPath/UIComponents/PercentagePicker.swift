import SwiftUI

struct PercentagePicker: View {
    @Binding var percentage: Double?
    @Environment(\.dismiss) private var dismiss

    @State private var pctString: String = ""
    @State private var shakeAttempts: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Percentage Display
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
                .padding(.horizontal, 24)
                .modifier(Shake(animatableData: CGFloat(shakeAttempts)))
                .animation(.default, value: shakeAttempts)

                Spacer()

                // Keypad
                CustomNumberPad(
                    text: $pctString,
                    maxFractionDigits: 0,
                    maxAmount: 100
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
                        if let val = Double(pctString) {
                            percentage = val
                        } else if pctString.isEmpty {
                            percentage = nil
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if let p = percentage {
                pctString = String(format: "%.0f", p)
            }
        }
    }
}
