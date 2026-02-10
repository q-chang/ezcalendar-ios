//
//  EZCalendarHorizontalPagingView.swift
//  MyCalendarComponent
//
//  Created by Wisanu Paunglumjeak on 16/12/2567 BE.
//

import SwiftUI

/**
 # 📖 Component: `EZCalendarHorizontalPagingView`

 The `EZCalendarHorizontalPagingView` provides a smooth, full-width paging experience. It allows users to swipe horizontally between months while keeping the UI perfectly aligned and synchronized with a `currentMonth` binding.

 ## 🛠️ Key Features

 * **View-Aligned Paging:** Uses SwiftUI's native scroll-targeting to snap perfectly to each month.
 * **Smart Synchronization:** Two-way binding ensures that swiping updates the `currentMonth` date, and programmatically changing the date scrolls the view to the correct month.
 * **Flexible Headers:** Choose whether the weekday headers (Sun, Mon, Tue) stay fixed at the top or scroll away with each month.
 * **Efficient Memory Use:** Powered by `LazyHStack`, only the visible months are rendered.

 ---

 ## 🚀 Usage

 ```swift
 @State private var currentMonth = Date()
 @State private var months: [CalendarMonth] = [...] // Your array of months

 EZCalendarHorizontalPagingView(
     withCalendar: .current,
     currentMonth: $currentMonth,
     calendarMonths: $months,
     weekdayItemViewContent: { title in
         Text(title).bold()
     },
     dayItemViewContent: { day in
         Text("\(day.dayNumber)")
             .frame(maxWidth: .infinity, minHeight: 40)
     }
 )
 .gridLineColor(.secondary.opacity(0.1))
 .weekdayScrollable(false) // Keep header fixed at the top

 ```

 ---

 ## ⚙️ Configuration & Modifiers

 ### Initialization Parameters

 | Parameter | Description |
 | --- | --- |
 | `withCalendar` | The `Calendar` instance to use for date math. |
 | `currentMonth` | A `@Binding` to the Date representing the currently visible month. |
 | `calendarMonths` | A `@Binding` to the data source array. |
 | `weekdayItemViewContent` | View builder for the weekday header cells. |
 | `dayItemViewContent` | View builder for the individual calendar day cells. |

 ### View Modifiers

 * **`.gridLineColor(Color?)`**: Pass down a color to the underlying month grids to show/hide separators.
 * **`.weekdayScrollable(Bool)`**:
 * `false` (Default): The "Sun, Mon, Tue" header is static at the top of the VStack.
 * `true`: Each month has its own header that scrolls horizontally with it.



 ---

 ## 🧠 Under the Hood: Sync Logic

 The view maintains a seamless connection between the scroll position and your app's state:

 1. **Scroll-to-Date:** When your code updates `currentMonth`, an `.onChange` modifier triggers an animation that snaps the `activeCalendarMonthHash` to the corresponding month.
 2. **Date-to-Scroll:** When a user finishes swiping, the `activeCalendarMonthHash` updates. The view then calculates the new `currentMonth` and updates your binding on the main thread.
 3. **Container Alignment:** Using `.containerRelativeFrame(.horizontal)`, each month is guaranteed to take up exactly the width of the screen, regardless of device size.
 */
public struct EZCalendarHorizontalPagingView<WeekdayItemView, DayItemView>: View
where WeekdayItemView: View, DayItemView: View {
    
    var calendar: Calendar
    var locale: Locale
    var weekDayTitles: [String]?
    @State var activeCalendarMonthHash: String? = nil
    @Binding public var currentMonth: Date
    @Binding public var calendarMonths: [CalendarMonth]
    
    public var weekdayItemViewContent: (String) -> WeekdayItemView
    public var dayItemViewContent: (CalendarDay) -> DayItemView
    
    public init(
        withCalendar calendar: Calendar,
        weekDayTitles: [String]? = nil,
        currentMonth: Binding<Date>,
        calendarMonths: Binding<[CalendarMonth]>,
        @ViewBuilder weekdayItemViewContent: @escaping (String) -> WeekdayItemView,
        @ViewBuilder dayItemViewContent: @escaping (CalendarDay) -> DayItemView
    ) {
        self.calendar = calendar
        self.locale = calendar.locale ?? Locale.current
        self.weekDayTitles = weekDayTitles
        self._currentMonth = currentMonth
        self._calendarMonths = calendarMonths
        self.weekdayItemViewContent = weekdayItemViewContent
        self.dayItemViewContent = dayItemViewContent
    }
    
    var gridLineColor: Color? = nil
    public func gridLineColor(_ color: Color?) -> Self {
        guard let color else {
            return self
        }
        
        var newView = self
        newView.gridLineColor = color
        return newView
    }
    
    var isWeekdayScrollable: Bool = false
    public func weekdayScrollable(_ isWeekdayScrollable: Bool) -> Self {
        var view = self
        view.isWeekdayScrollable = isWeekdayScrollable
        return view
    }

    public var body: some View {
        VStack(spacing: 0) {
            
            if !isWeekdayScrollable {
                EZCalendarWeekdayHeaderView(weekDayTitles: weekDayTitles, locale: locale, weekdayItemViewContent: weekdayItemViewContent)
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    Group {
                        ForEach(calendarMonths, id: \.self) { calendarMonth in
                            VStack(spacing: 0) {
                                
                                if isWeekdayScrollable {
                                    EZCalendarWeekdayHeaderView(weekDayTitles: weekDayTitles, locale: locale, weekdayItemViewContent: weekdayItemViewContent)
                                }
                                
                                EZCalendarItemView(
                                    calendarMonth,
                                    calendar: calendar,
                                    dayItemViewContent: dayItemViewContent
                                )
                                .gridLineColor(self.gridLineColor)
                            }
                            .id(calendarMonth.hashString)
                        }
                    }
                    .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $activeCalendarMonthHash)
            .scrollIndicators(.never)
        }
        .onChange(of: activeCalendarMonthHash) { _, activeCalendarMonthHash in
            DispatchQueue.main.async {
                guard let currentMonth = getCurrentMonth(fromUUID: activeCalendarMonthHash) else {
                    return
                }
                
                self.currentMonth = currentMonth
            }
        }
        .onChange(of: currentMonth) { _, newValue in
            guard let calendarMonth = getCalendarMonth(fromDate: newValue) else {
                return
            }
            
            withAnimation {
                activeCalendarMonthHash = calendarMonth.hashString
            }
        }
        .onAppear{
            activeCalendarMonthHash = "\(getCalendarMonth(fromDate: currentMonth)?.hashValue ?? 0)"
        }
    }
    
    func getCalendarMonth(fromDate date: Date) -> CalendarMonth? {
        let components = calendar.dateComponents([.month, .year], from: date)
        
        guard let calendarMonth = self.calendarMonths.first(where: {
            $0.year == components.year && $0.month == components.month
        }) else {
            return nil
        }
        
        return calendarMonth
    }
    
    func getCurrentMonth(fromUUID uuid: String?) -> Date? {
        
        guard let calendarMonth = calendarMonths.first(where: { $0.hashString == uuid }) else {
            return nil
        }
        
        
        return Date.from(year: calendarMonth.year, month: calendarMonth.month, day: 1, calendar: calendar)
    }
}
