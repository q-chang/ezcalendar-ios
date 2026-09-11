//
//  DemoRangeSelectionViewModel.swift
//  Demo
//
//  Created by wisanu on 11/9/2569 BE.
//

import Foundation
import EZCalendar

class DemoRangeSelectionViewModel: ObservableObject {

    let calendar: Calendar
    let weekdayTitles: [String]
    let firstMonth: Date
    let lastMonth: Date

    @Published var calendarMonths: [CalendarMonth]

    /// The range the form shows. The sheet edits a copy and writes it back only
    /// when the user confirms.
    @Published var selection = DateRangeSelection()

    init(withCalendar calendar: Calendar) {
        let thisMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let firstMonth = calendar.date(byAdding: .year, value: -1, to: thisMonth) ?? thisMonth
        let lastMonth = calendar.date(byAdding: .year, value: 2, to: thisMonth) ?? thisMonth

        self.calendar = calendar
        self.weekdayTitles = calendar.veryShortWeekdaySymbols
        self.firstMonth = firstMonth
        self.lastMonth = lastMonth
        self.calendarMonths = EZCalendarHelper.generateCalendarMonths(
            startDate: firstMonth,
            endDate: lastMonth,
            calendar: calendar
        )
    }

    /// The month the picker opens on: the selection's Start, else today.
    func initialMonth(for selection: DateRangeSelection) -> Date {
        let anchor = selection.startDate ?? Date()
        return calendar.dateInterval(of: .month, for: anchor)?.start ?? anchor
    }

    /// `month` moved by `value` months, or `nil` when that leaves the paging range.
    func month(_ month: Date, offsetBy value: Int) -> Date? {
        guard let date = calendar.date(byAdding: .month, value: value, to: month),
              date >= firstMonth,
              date <= lastMonth else {
            return nil
        }
        return date
    }

    func format(_ date: Date, dateFormat: String = "d MMMM yyyy") -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    /// The line under the grid, e.g. "เลือก 3 กรกฎาคม 2569 - 14 กรกฎาคม 2569".
    func summary(of selection: DateRangeSelection) -> String {
        guard let startDate = selection.startDate else {
            return "เลือกวันเริ่มต้น"
        }
        let end = selection.endDate.map { format($0) } ?? "เลือกวันสิ้นสุด"
        return "เลือก \(format(startDate)) - \(end)"
    }
}
