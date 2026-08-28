import SwiftUI

struct InlineExpenseComponent: View {
    @Environment(ParticipantStore.self) private var participantStore
    @Bindable var vm: ManualExpenseViewModel

    @State private var isShowingAmountSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Amount
            Button {
                isShowingAmountSheet = true
            } label: {
                HStack {
                    HStack(spacing: 12) {
                        InlineExpenseIcon(systemName: "dollarsign")
                        Text("Amount").foregroundStyle(.primary)
                    }
                    Spacer()
                    if vm.amountIsEmpty {
                        Text("Add amount")
                            .foregroundStyle(Color.secondary)
                    } else {
                        Text("\(vm.currencySymbol)\(vm.formattedAmount)")
                            .foregroundStyle(Color.primary)
                    }
                }
                .padding(.vertical)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isShowingAmountSheet) {
                AmountInputView(text: $vm.amountText, currency: $vm.selectedCurrency)
            }

            Divider().padding(.leading)

            // Paid By
            HStack {
                HStack(spacing: 12) {
                    InlineExpenseIcon(systemName: "creditcard")
                    Text("Paid by").foregroundStyle(.primary)
                }
                Spacer()
                Menu {
                    Picker(selection: $vm.paidById) {
                        ForEach(participantStore.participants, id: \.id) { p in
                            Text(p.displayName).tag(p.id ?? "")
                        }
                    } label: {
                        EmptyView()
                    }
                } label: {
                    if let p = participantStore.participants.first(where: { $0.id == vm.paidById }) {
                        HStack {
                            ParticipantAvatar(participant: p, size: .small)
                            Text(p.displayName).foregroundStyle(Color.primary)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.vertical, 8)

            Divider().padding(.leading)

            // Split Toggle
            Toggle(
                isOn: Binding(
                    get: { vm.equalParticipants.count > 1 || vm.splitType != .equal },
                    set: { isSplit in
                        if isSplit {
                            vm.splitType = .equal
                            vm.equalParticipants = Set(participantStore.participants.compactMap { $0.id })
                        } else {
                            vm.splitType = .equal
                            vm.equalParticipants = [vm.paidById]
                        }
                    }
                )
            ) {
                HStack(spacing: 12) {
                    InlineExpenseIcon(systemName: "person.2.fill")
                    Text("Split Expense").foregroundStyle(.primary)
                }
            }
            .padding(.vertical)

            if vm.equalParticipants.count > 1 || vm.splitType != .equal {
                Divider().padding(.leading)

                // Split Type Picker
                Picker("Split Type", selection: $vm.splitType) {
                    ForEach(SplitType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical)

                // Split List
                ExpenseSplitSection(vm: vm)
                    .padding(.bottom, 16)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct InlineExpenseIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color.gray.opacity(0.6), in: Circle())
    }
}
