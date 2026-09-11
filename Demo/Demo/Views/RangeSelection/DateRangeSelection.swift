//
//  DateRangeSelection.swift
//  Demo
//
//  Created by wisanu on 11/9/2569 BE.
//

import Foundation

/**
 The Start/End pair behind the range picker, and the tap rules that move it.

 | Current state | Tapped day | Result |
 | --- | --- | --- |
 | nothing selected | any | Start = day |
 | Start only | after Start | End = day |
 | Start only | same day as Start | End = Start — a one-day range |
 | Start only | before Start | Start = day, End stays empty |
 | Start + End | any | Start = day, End cleared — a new range begins |

 Dates are stored as the start of the day in the picker's calendar, so the
 comparisons below never trip over a time component.
 */
struct DateRangeSelection {
    var startDate: Date?
    var endDate: Date?

    var isComplete: Bool {
        startDate != nil && endDate != nil
    }

    mutating func select(_ date: Date, calendar: Calendar) {
        let day = calendar.startOfDay(for: date)

        // Nothing selected yet, or a finished range: this tap starts a new one.
        guard let startDate, endDate == nil else {
            self.startDate = day
            self.endDate = nil
            return
        }

        if day < startDate {
            self.startDate = day
        } else {
            self.endDate = day
        }
    }

    func isEndpoint(_ date: Date, calendar: Calendar) -> Bool {
        [startDate, endDate].contains { endpoint in
            endpoint.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        }
    }

    /// Whether `date` sits on the highlighted band. A one-day range has no band.
    func isInRange(_ date: Date, calendar: Calendar) -> Bool {
        guard let startDate,
              let endDate,
              !calendar.isDate(startDate, inSameDayAs: endDate) else {
            return false
        }
        let day = calendar.startOfDay(for: date)
        return day >= startDate && day <= endDate
    }
}
