import HorizonCalendar
import SwiftUI

struct DatePickerView: View {
    @StateObject private var vm: DatePickerVM
    var onCancel: () -> Void
    var onSubmit: (Date, Date) -> Void

    @State private var scrollToDate: Date?

    init(
        initialStartDate: Date? = nil,
        initialEndDate: Date? = nil,
        dateRange: ClosedRange<Date>? = nil,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (Date, Date) -> Void
    ) {
        self._vm = StateObject(wrappedValue: DatePickerVM(initialStartDate: initialStartDate, initialEndDate: initialEndDate, dateRange: dateRange))
        self.onCancel = onCancel
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            VStack {
                CalendarViewRepresentable(
                    vm: vm,
                    scrollToDate: $scrollToDate
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let start = vm.selectedStartDate, let end = vm.selectedEndDate {
                        if Calendar.current.isDate(start, inSameDayAs: end) {
                            Text(start.displayString())
                                .fontWeight(.bold)
                        } else {
                            HStack(spacing: 8) {
                                Text(start.displayString())
                                Image(systemName: "arrow.right")
                                Text(end.displayString())
                            }
                            .fontWeight(.bold)
                        }
                    } else if let start = vm.selectedStartDate {
                        Text(start.displayString())
                            .fontWeight(.bold)
                    } else {
                        Text("Select Dates")
                            .fontWeight(.bold)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .confirm) {
                        if let start = vm.selectedStartDate, let end = vm.selectedEndDate {
                            onSubmit(start, end)
                        } else if let start = vm.selectedStartDate {
                            onSubmit(start, start)
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(vm.selectedStartDate == nil)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button {
                        vm.resetSelection()
                    } label: {
                        Text("Clear")
                    }
                    .disabled(vm.selectedStartDate == nil)
                }

            }
        }
    }
}

struct CalendarViewRepresentable: UIViewRepresentable {
    @ObservedObject var vm: DatePickerVM
    @Binding var scrollToDate: Date?

    func makeUIView(context: Context) -> CalendarView {
        let calendarView = CalendarView(initialContent: makeContent())
        calendarView.backgroundColor = .clear

        calendarView.daySelectionHandler = { [calendar = vm.calendar] day in
            if let date = calendar.date(from: day.components) {
                vm.handleDaySelection(date)
                calendarView.setContent(self.makeContent())
            }
        }

        // Scroll to the selected start date or today's date initially
        DispatchQueue.main.async {
            calendarView.scroll(
                toMonthContaining: vm.selectedStartDate ?? Date(),
                scrollPosition: .firstFullyVisiblePosition(padding: 0),
                animated: false
            )
        }

        return calendarView
    }

    func updateUIView(_ uiView: CalendarView, context: Context) {
        uiView.setContent(makeContent())

        if let targetDate = scrollToDate {
            DispatchQueue.main.async {
                uiView.scroll(
                    toMonthContaining: targetDate,
                    scrollPosition: .firstFullyVisiblePosition(padding: 0),
                    animated: true
                )
                self.scrollToDate = nil
            }
        }
    }

    private func makeContent() -> CalendarViewContent {
        CalendarViewContent(
            calendar: vm.calendar,
            visibleDateRange: vm.minDate...vm.maxDate,
            monthsLayout: .vertical(options: VerticalMonthsLayoutOptions())
        )
        .interMonthSpacing(24)
        .verticalDayMargin(8)
        .horizontalDayMargin(0)
        .dayItemProvider { day in
            let date = vm.calendar.date(from: day.components) ?? Date()
            let isToday = vm.calendar.isDateInToday(date)
            let state = vm.state(for: date)
            let weekday = vm.calendar.component(.weekday, from: date)
            let isFirstDayOfWeek = weekday == vm.calendar.firstWeekday
            let isLastDayOfWeek = weekday == ((vm.calendar.firstWeekday + 5) % 7 + 1)

            return CalendarDayCell(
                dayNumber: day.day,
                state: state,
                isToday: isToday,
                isFirstDayOfWeek: isFirstDayOfWeek,
                isLastDayOfWeek: isLastDayOfWeek
            )
            .calendarItemModel
        }
        .monthHeaderItemProvider { month in
            var text = ""
            if let date = vm.calendar.date(from: month.components) {
                text = DateFormatter.monthYear.string(from: date)
            }
            return HStack {
                Text(text)
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .calendarItemModel
        }
        .dayOfWeekItemProvider { month, weekdayIndex in
            let weekdayStrings = vm.calendar.veryShortWeekdaySymbols
            let text = weekdayStrings[weekdayIndex]

            return Text(text)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .calendarItemModel
        }
    }
}

struct CalendarDayCell: View {
    let dayNumber: Int
    let state: DaySelectionState
    let isToday: Bool
    let isFirstDayOfWeek: Bool
    let isLastDayOfWeek: Bool

    var themeColor: Color = .blue

    var body: some View {
        Text("\(dayNumber)")
            .font(.system(size: 18, weight: isToday ? .bold : .regular))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(backgroundView)
    }

    private var textColor: Color {
        switch state {
        case .start, .end: return .white
        case .outOfRange: return Color(UIColor.tertiaryLabel)
        default: return isToday ? themeColor : .primary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            switch state {
            case .between:
                Rectangle()
                    .fill(themeColor.opacity(0.3))
                    .frame(height: 40)
                    .clipShape(
                        .rect(
                            topLeadingRadius: isFirstDayOfWeek ? 20 : 0,
                            bottomLeadingRadius: isFirstDayOfWeek ? 20 : 0,
                            bottomTrailingRadius: isLastDayOfWeek ? 20 : 0,
                            topTrailingRadius: isLastDayOfWeek ? 20 : 0
                        )
                    )
            case .start(let isSameDay):
                if !isSameDay && !isLastDayOfWeek {
                    HStack(spacing: 0) {
                        Color.clear
                        themeColor.opacity(0.3)
                    }.frame(height: 40)
                }
                Circle().fill(themeColor).frame(width: 40, height: 40)
            case .end:
                if !isFirstDayOfWeek {
                    HStack(spacing: 0) {
                        themeColor.opacity(0.3)
                        Color.clear
                    }.frame(height: 40)
                }
                Circle().fill(themeColor).frame(width: 40, height: 40)
            case .unselected, .outOfRange:
                EmptyView()
            }
        }
    }
}
