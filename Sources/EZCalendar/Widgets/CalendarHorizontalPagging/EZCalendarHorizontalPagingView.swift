//
//  EZCalendarHorizontalPagingView.swift
//  MyCalendarComponent
//
//  Created by Wisanu Paunglumjeak on 16/12/2567 BE.
//

import SwiftUI

public struct EZCalendarHorizontalPagingView<WeekdayItemView, DayItemView>: View
where WeekdayItemView: View, DayItemView: View {
    
    var calendar: Calendar
    var locale: Locale
    @State var activeCalendarMonthHash: String? = nil
    @Binding public var currentMonth: Date
    @Binding public var calendarMonths: [CalendarMonth]
    
    public var weekdayItemViewContent: (String) -> WeekdayItemView
    public var dayItemViewContent: (CalendarDay) -> DayItemView
    
    public init(
        withCalendar calendar: Calendar,
        locale: Locale,
        currentMonth: Binding<Date>,
        calendarMonths: Binding<[CalendarMonth]>,
        @ViewBuilder weekdayItemViewContent: @escaping (String) -> WeekdayItemView,
        @ViewBuilder dayItemViewContent: @escaping (CalendarDay) -> DayItemView
    ) {
        self.calendar = calendar
        self.locale = locale
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
                EZCalendarWeekdayHeaderView(locale: locale, weekdayItemViewContent: weekdayItemViewContent)
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    Group {
                        ForEach(calendarMonths, id: \.self) { calendarMonth in
                            VStack(spacing: 0) {
                                
                                if isWeekdayScrollable {
                                    EZCalendarWeekdayHeaderView(locale: locale, weekdayItemViewContent: weekdayItemViewContent)
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
