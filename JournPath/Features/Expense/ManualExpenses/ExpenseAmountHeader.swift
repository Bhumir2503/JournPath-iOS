import SwiftUI

struct ExpenseAmountHeader: View {
    let currencySymbol: String
    let formattedAmount: String
    let invalidAttempts: Int
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(currencySymbol)
                .font(.system(size: 40, weight: .regular))
                .padding(.bottom, 16)

            Text(formattedAmount)
                .font(.system(size: 100, weight: .regular))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .contentTransition(.numericText())
        .shake(trigger: invalidAttempts)
        .padding(.horizontal, 24)
    }
}
