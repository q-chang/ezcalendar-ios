//
//  CalendarHorizontalPaggingViewModel.swift
//  Demo
//
//  Created by Wisanu Paunglumjeak on 12/1/2568 BE.
//

import Foundation
import EZCalendar

class CalendarHorizontalPaggingViewModel: ObservableObject {
    
    @Published var calendar: Calendar
    @Published var weekdayTitles: [String]
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var currentMonth: Date
    
    @Published var calendarMonths: [CalendarMonth]
    
    init(withCalendar calendar: Calendar = Calendar.init(identifier: .gregorian)) {
        let nowComponents = calendar.dateComponents([.year, .month], from: Date())
        let startDate = Date.from(year: nowComponents.year!, month: 1, day: 1, calendar: calendar)!
        let endDate = Date.from(year: nowComponents.year! + 100, month: 12, day: 30, calendar: calendar)!
        
        self.calendar = calendar
        self.weekdayTitles = calendar.veryShortWeekdaySymbols
        self.startDate = startDate
        self.endDate = endDate
        self.currentMonth = Date.from(year: nowComponents.year!, month: nowComponents.month!, day: 1, calendar: calendar)!
        self.calendarMonths = EZCalendarHelper.generateCalendarMonths(startDate: startDate, endDate: endDate, calendar: calendar)
    }
    
    func isDateGreaterThanOrEqualStartDate(_ date: Date) -> Bool {
        date >= startDate
    }
    
    func isDateLessThanOrEqualEndDate(_ date: Date) -> Bool {
        date <= endDate.endOfMonth
    }

    func updateEvents(_ monthDate: Date) {
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + .milliseconds(500)) {
            self.generateEvents(monthDate)
        }
    }
    
    private func generateEvents(_ monthDate: Date) {
        Task { @MainActor in
            
            guard let index = calendarMonths.firstIndex(where: { self.isCalendarMonthMatchWith(monthDate, of: $0) }) else {
                return
            }
            
            let calendarMonth = calendarMonths[index]
            
            let events = getEvent(month: calendarMonth.month, year: calendarMonth.year)
            calendarMonths[index] = CalendarMonth(month: calendarMonth.month, year: calendarMonth.year, events: events)
        }
    }
    
    private func getEvent(month: Int, year: Int) -> [CalendarEvent] {
        
        var events: [CalendarEvent] = []
        
        switch month % 3 {
        case 0:
            events.append(
                contentsOf: [
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 1, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 7, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 12, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 16, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 20, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 22, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 25, calendar: calendar)!)
                ]
            )
        case 1:
            events.append(
                contentsOf: [
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 2, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 4, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 6, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 8, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 12, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 16, calendar: calendar)!),
                    CalendarEvent(eventDate: Date.from(year: year, month: month, day: 19, calendar: calendar)!)
                ]
            )
        case 2:
            break
        default:
            break
        }
        
        return events
    }
    
    private func isCalendarMonthMatchWith(_ monthDate: Date, of calendarMonth: CalendarMonth) -> Bool {
        let month = monthDate.get(.month, calendar: calendar)
        let year = monthDate.get(.year, calendar: calendar)
        
        return calendarMonth.month == month && calendarMonth.year == year
    }
}
