import SwiftUI

extension ActivityFormView {
    @ViewBuilder
    var dateAndTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                HStack {
                    Text("Starts")
                    Spacer()
                    DatePicker(
                        "", selection: $vm.item.startTime,
                        in: vm.selectableRange,
                        displayedComponents: vm.item.allDay ? .date : [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .fixedSize()
                    .environment(\.timeZone, vm.destinationTimeZone)
                    .onChange(of: vm.item.startTime) {
                        withAnimation { vm.validateEndDate() }
                    }
                }
                .padding()

                Divider().padding(.leading, 16)

                HStack {
                    Text("Ends")
                    Spacer()
                    DatePicker(
                        "", selection: $vm.item.endTime,
                        in: vm.endSelectableRange,
                        displayedComponents: vm.item.allDay ? .date : [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .fixedSize()
                    .environment(\.timeZone, vm.destinationTimeZone)
                }
                .padding()

                Divider().padding(.leading, 16)

                Toggle("All Day", isOn: $vm.item.allDay)
                    .padding()
                    .onChange(of: vm.item.allDay) { _, newValue in
                        withAnimation(.easeInOut) { vm.handleAllDayChange(newValue) }
                    }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            HStack(spacing: 6) {
                Image(
                    systemName: vm.hasResolvedTimeZone
                        ? "info.circle.fill"
                        : "exclamationmark.triangle.fill")
                Text(
                    vm.hasResolvedTimeZone
                        ? "Times shown in \(vm.timeZoneDisplayName)"
                        : "Couldn't determine this place's time zone — using \(vm.timeZoneDisplayName).")
            }
            .padding(.horizontal, 12)
            .font(.caption)
            .foregroundStyle(vm.hasResolvedTimeZone ? Color.secondary : Color.orange)
        }
    }
}
