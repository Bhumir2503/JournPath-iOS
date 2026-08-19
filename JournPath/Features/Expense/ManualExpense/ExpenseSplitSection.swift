import SwiftUI

struct ExpenseSplitSection: View {
    @Environment(ParticipantStore.self) private var participantStore

    @Binding var splitType: SplitType
    @Binding var evenlySplitParticipants: Set<String>
    @Binding var manualSplits: [String: String]
    @Binding var percentageSplits: [String: String]
    
    @Binding var editingManualSplitFor: String?
    @Binding var editingPercentageSplitFor: String?
    
    @Binding var selectedCurrency: String
    
    let amountPerPerson: Double
    let currencySymbol: String
    
    let manualSplitLimit: (String) -> Double
    let percentageSplitLimit: (String) -> Double

    var body: some View {
        ForEach(participantStore.participants, id: \.id) { p in
            HStack {
                ParticipantAvatar(participant: p, size: .small)
                Text(p.displayName)
                Spacer()

                switch splitType {
                case .evenly:
                    Button {
                        withAnimation {
                            if evenlySplitParticipants.contains(p.id ?? "") {
                                if evenlySplitParticipants.count > 1 {
                                    evenlySplitParticipants.remove(p.id ?? "")
                                }
                            } else {
                                evenlySplitParticipants.insert(p.id ?? "")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if evenlySplitParticipants.contains(p.id ?? "") {
                                Text(amountPerPerson.formatted(.currency(code: selectedCurrency)))
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: evenlySplitParticipants.contains(p.id ?? "") ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(evenlySplitParticipants.contains(p.id ?? "") ? Color.brand : Color.gray.opacity(0.3))
                                .font(.title3)
                        }
                    }
                    .buttonStyle(.plain)
                    
                case .manually:
                    Button {
                        editingManualSplitFor = p.id
                    } label: {
                        Text(manualSplits[p.id ?? ""]?.isEmpty == false ? "\(currencySymbol)\(manualSplits[p.id ?? ""]!)" : "—")
                            .foregroundStyle(manualSplits[p.id ?? ""]?.isEmpty == false ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: Binding(
                        get: { editingManualSplitFor == p.id },
                        set: { if !$0 { editingManualSplitFor = nil } }
                    )) {
                        AmountInputView(
                            text: Binding(
                                get: { manualSplits[p.id ?? ""] ?? "" },
                                set: { manualSplits[p.id ?? ""] = $0 }
                            ),
                            currency: $selectedCurrency,
                            isFixedCurrency: true,
                            limit: manualSplitLimit(p.id ?? "")
                        )
                        .presentationDetents([.large])
                    }
                    
                case .percentage:
                    Button {
                        editingPercentageSplitFor = p.id
                    } label: {
                        Text(percentageSplits[p.id ?? ""]?.isEmpty == false ? "\(percentageSplits[p.id ?? ""]!)%" : "—")
                            .foregroundStyle(percentageSplits[p.id ?? ""]?.isEmpty == false ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: Binding(
                        get: { editingPercentageSplitFor == p.id },
                        set: { if !$0 { editingPercentageSplitFor = nil } }
                    )) {
                        PercentageInputView(
                            text: Binding(
                                get: { percentageSplits[p.id ?? ""] ?? "" },
                                set: { percentageSplits[p.id ?? ""] = $0 }
                            ),
                            limit: percentageSplitLimit(p.id ?? "")
                        )
                        .presentationDetents([.large])
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
