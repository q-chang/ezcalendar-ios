//
//  EZCalendarItemViewModel.swift
//  EZCalendar
//
//  Created by Wisanu Paunglumjeak on 25/12/2567 BE.
//

import Foundation
import SwiftUI

/**
 ## 🏗️ Initialization: Setting the Engine in Motion

 The `init` for `EZCalendarItemViewModel` ensures that the moment your calendar view appears, the data is already processed, organized into weeks, and ready to be rendered.

 ### 🛠️ Implementation

 ```swift
 init(calendarMonth: CalendarMonth, calendar: Calendar) {
     self.calendarMonth = calendarMonth
     self.calendar = calendar
     
     // Automatically triggers the grid generation logic
     self.calendarWeeks = self.generateCalendar()
 }

 ```

 ---

 ## ⚡ Key Responsibilities

 1. **Dependency Injection:** By passing in the `calendarMonth` and `calendar`, the ViewModel doesn't have to "guess" the user's settings. It uses exactly what the parent view provides.
 2. **Immediate Data Readiness:** It calls `self.generateCalendar()` immediately. This means `calendarWeeks` is never empty for a frame—preventing that awkward "flicker" where a UI might look empty before the data loads.
 3. **State Sync:** It maps the raw configuration (`CalendarMonth`) into the UI-ready structure (`[CalendarWeek]`) right at birth.

 ---

 ## 🚀 Usage in Parent Views

 Because of this clean initializer, you can easily create multiple calendar months (like a scrolling list) by simply passing the data down:

 ```swift
 struct CalendarListView: View {
     let months: [CalendarMonth] // Your data source
     
     var body: some View {
         ScrollView {
             ForEach(months) { month in
                 // Each ItemView gets its own ViewModel initialized with specific data
                 EZCalendarMonthView(month: month)
             }
         }
     }
 }

 ```

 ---

 ## 💡 Architectural Insight

 By separating the `CalendarMonth` (the data) from the `EZCalendarItemViewModel` (the logic), you've made your library **highly testable**. You can initialize this ViewModel in a Unit Test with a mock calendar and immediately check if `calendarWeeks` has the correct number of rows for February in a leap year, for example.
 */
class EZCalendarItemViewModel: ObservableObject {
    
    var calendar: Calendar
    @Published var calendarMonth: CalendarMonth
    @Published var calendarWeeks: [CalendarWeek] = []
    
    init(calendarMonth: CalendarMonth, calendar: Calendar) {
        self.calendarMonth = calendarMonth
        self.calendar = calendar
        self.calendarWeeks = self.generateCalendar()
    }
    
    /**
     This is the "Grand Orchestrator" of your library. It pulls together the logic for the current month, previous padding, and next padding into a single cohesive array of weeks.

     ---

     # 🏗️ Core Engine: `generateCalendar()`

     The `generateCalendar()` method is the master function that builds the entire grid structure for a given month. It iterates through the days and weeks, calling our specialized "build" helpers to construct a complete list of `CalendarWeek` objects.

     ## 🛠️ Logic Breakdown

     ### 1. Initial Calculations

     Before building the grid, the method determines the boundaries of the month:

     * **First & Last Dates:** Identifies the precise start and end of the month.
     * **Range:** Determines how many days are in the month (e.g., 28, 30, or 31).
     * **Weekday Offsets:** Finds out which day of the week the month starts and ends on. This is critical for knowing where to place "Day 1."

     ### 2. The Nested Loop Strategy

     The method uses a `while` loop to iterate through the days and a nested `for` loop (1...7) to group them into weeks.

     * **The First Week:** If we are at the start of the month, the logic checks the `firstDayOfWeekInMonth`. Any slots before this are filled using the **Previous Month** logic.
     * **The Middle Weeks:** Standard progression of days using **Current Month** logic.
     * **The Final Week:** Once the `dayOfMonth` exceeds the number of days in the month, it fills the remaining slots in the 7-day row using **Next Month** logic.

     ---

     ## 📄 Implementation Summary

     ```swift
     private func generateCalendar() -> [CalendarWeek] {
         // 1. Guard against invalid date math
         guard let firstDateOfMonth = ...
         
         // 2. Setup counters
         var calendarWeeks: [CalendarWeek] = []
         var dayOfMonth = 1
         
         // 3. Build until all days of the month are placed
         while dayOfMonth <= numberOfDaysInMonth {
             var calendarDays: [CalendarDay] = []
             
             for weekDay in 1...7 {
                 // Logic to decide between Previous, Current, or Next month builders
                 // ...
             }
             
             // Group the 7 days into a Week object
             calendarWeeks.append(CalendarWeek(calendarDays: calendarDays))
         }
         
         return calendarWeeks
     }

     ```

     ---

     ## 🧩 Architectural Strengths

     * **Safe Failure:** By using `guard` statements for every date calculation, the method ensures that it returns an empty array `[]` rather than crashing if the system's calendar settings are corrupted.
     * **Structural Consistency:** Every `CalendarWeek` returned is guaranteed to have exactly **7 days**, making it perfectly compatible with SwiftUI’s `HStack` or `Grid` layouts.
     * **Logic-View Separation:** This method returns a data structure (`[CalendarWeek]`), not a view. This allows developers to use the data to build any UI they want (List, Grid, or even a Canvas).
     */
    private func generateCalendar() -> [CalendarWeek] {
        
        guard let firstDateOfMonth = Date.from(year: calendarMonth.year, month: calendarMonth.month, day: 1, calendar: calendar) else {
            return []
        }
        
        guard let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDateOfMonth)?.count else {
            return []
        }
        
        guard let lastDateOfMonth = Date.from(year: calendarMonth.year, month: calendarMonth.month, day: numberOfDaysInMonth, calendar: calendar) else {
            return []
        }
        
        guard let firstDayOfWeekInMonth = calendar.dateComponents([.weekday], from: firstDateOfMonth).weekday else {
            return []
        }
        
        guard let lastDayOfWeekInMonth = calendar.dateComponents([.weekday], from: lastDateOfMonth).weekday else {
            return []
        }
        
        var calendarWeeks: [CalendarWeek] = []
        var dayOfMonth = 1
        
        while dayOfMonth <= numberOfDaysInMonth {
            var calendarDays: [CalendarDay] = []
            
            for weekDay in 1...7 {
                if calendarWeeks.isEmpty {
                    /* If first week of month */
                    if weekDay >= firstDayOfWeekInMonth {
                        /* If first day of week in month in range*/
                        calendarDays.append(
                            self.buildCalendarDayInCurrentMonth(dayOfMonth)
                        )
                        dayOfMonth += 1
                    } else {
                        let diffDay = weekDay - firstDayOfWeekInMonth
                        calendarDays.append(
                            self.buildCalendarDayInPreviousMonth(startDateOfMonth: firstDateOfMonth, diffDayFromStart: diffDay)
                        )
                    }
                } else {
                    if dayOfMonth <= numberOfDaysInMonth {
                        /* If first day of week in month in range*/
                        calendarDays.append(
                            self.buildCalendarDayInCurrentMonth(dayOfMonth)
                        )
                        dayOfMonth += 1
                    } else {
                        let diffDay = weekDay - lastDayOfWeekInMonth
                        calendarDays.append(
                            self.buildCalendarDayInPreviousMonth(startDateOfMonth: lastDateOfMonth, diffDayFromStart: diffDay)
                        )
                    }
                }
            }
            
            calendarWeeks.append(
                CalendarWeek(calendarDays: calendarDays)
            )
        }
        
        return calendarWeeks
    }
    
    /**
     ## 🏗 Data Factory: `buildCalendarDayInCurrentMonth`

     The `buildCalendarDayInCurrentMonth` method is responsible for constructing each individual day within the active month's grid. It acts as the bridge between raw numeric counts (e.g., "Day 15") and the actual `CalendarDay` model used by your SwiftUI views.

     ### 🛠 Implementation

     ```swift
     private func buildCalendarDayInCurrentMonth(_ dayOfMonth: Int) -> CalendarDay {
         // 1. Generate a valid Date object from the current month's context
         let date = Date.from(
             year: self.calendarMonth.year,
             month: self.calendarMonth.month,
             day: dayOfMonth,
             calendar: calendar
         )
         
         // 2. Return a model containing the date and pre-calculated event status
         return CalendarDay(
             date: date,
             hasEvents: hasEvents(from: date)
         )
     }

     ```

     ---

     ## 🧱 Key Responsibilities

     1. **Date Assembly:** It uses a `Date.from` helper (likely an extension you’ve written) to combine the year and month stored in the ViewModel with the specific day number. This ensures time zones and calendar settings are respected.
     2. **Contextual Awareness:** Every day generated through this method is automatically aware of whether it contains events by calling the `hasEvents(from:)` helper we documented earlier.
     3. **Encapsulation:** By keeping this logic private, the ViewModel ensures that the UI only ever sees the final, ready-to-use `CalendarDay` objects, rather than having to perform these calculations inside a `ForEach` loop.
     */
    private func buildCalendarDayInCurrentMonth(_ dayOfMonth: Int) -> CalendarDay {
        
        let date = Date.from(year: self.calendarMonth.year, month: self.calendarMonth.month, day: dayOfMonth, calendar: calendar)
        
        return CalendarDay(
            date: date,
            hasEvents: hasEvents(from: date)
        )
    }
    
    /**

     ## 🛠 Component: Previous Month Fill Logic

     The `buildCalendarDayInPreviousMonth` method ensures that your calendar grid always starts on the correct weekday, even if the 1st of the month falls in the middle of the week.

     ### 🛠 Implementation

     ```swift
     private func buildCalendarDayInPreviousMonth(startDateOfMonth: Date, diffDayFromStart: Int) -> CalendarDay {
         // 1. Calculate the exact date by subtracting the offset from the month's start date
         guard let dateOfPreviousMonth = startDateOfMonth.addingComponentsOfDate(day: diffDayFromStart) else {
             return CalendarDay() // Returns an empty/default day if calculation fails
         }
         
         // 2. Return a day marked as 'not in the current month'
         return CalendarDay(
             date: dateOfPreviousMonth,
             isCurrentMonth: false
         )
     }

     ```

     ---

     ## 🧩 Key Logic: The Offset Calculation

     To create a seamless visual experience, this method works backward from the `startDateOfMonth`.

     * **`startDateOfMonth`**: The `Date` object representing the 1st day of the current month.
     * **`diffDayFromStart`**: A negative integer (e.g., `-3`) representing how many days to look back.
     * **`isCurrentMonth: false`**: This flag is crucial. It allows your SwiftUI views to dim or hide these days (e.g., making them light gray) to distinguish them from the active month.
     */
    private func buildCalendarDayInPreviousMonth(startDateOfMonth: Date, diffDayFromStart: Int) -> CalendarDay {
        
        guard let dateOfPreviousMonth = startDateOfMonth.addingComponentsOfDate(day: diffDayFromStart) else {
            return CalendarDay()
        }
        
        return CalendarDay(
            date: dateOfPreviousMonth,
            isCurrentMonth: false
        )
    }
    
    /**
     ## 🛠 Component: Next Month Fill Logic

     The `buildCalendarDayInNextMonth` method calculates the dates required to fill the remaining slots in the final week of the calendar grid. This creates a consistent 7-column layout regardless of which day the month ends on.

     ### 🛠 Implementation

     ```swift
     private func buildCalendarDayInNextMonth(endDateOfMonth: Date, diffDayFromEnd: Int) -> CalendarDay {
         // 1. Calculate the date by adding the offset to the month's end date
         guard let dateOfNextMonth = endDateOfMonth.addingComponentsOfDate(day: diffDayFromEnd) else {
             return CalendarDay() // Fallback to a default object
         }
         
         // 2. Return a day marked as outside the current month scope
         return CalendarDay(
             date: dateOfNextMonth,
             isCurrentMonth: false
         )
     }

     ```

     ---

     ## 🧩 How it Completes the Grid

     While the "Previous Month" logic looks at the start, this logic looks at the `endDateOfMonth` (e.g., October 31st).

     * **`endDateOfMonth`**: The last day of the currently displayed month.
     * **`diffDayFromEnd`**: A positive integer (e.g., `1`, `2`, `3`) that increments to find the following month's leading days.
     * **Visual Symmetry**: By using the same `isCurrentMonth: false` flag as the previous month, you maintain visual consistency, signaling to the user that these dates are "overflow" from the next month.

     ---

     ## 📊 Summary of the Day Building Logic

     With these three methods combined, your ViewModel has a complete toolkit to construct a perfectly aligned 7x5 or 7x6 grid:

     | Method | Source Point | Month Scope | Typical Style |
     | --- | --- | --- | --- |
     | `buildCalendarDayInPreviousMonth` | Start of Month | `false` | Dimmed / Secondary |
     | `buildCalendarDayInCurrentMonth` | Month Constants | `true` | Primary / Bold |
     | `buildCalendarDayInNextMonth` | End of Month | `false` | Dimmed / Secondary |
     */
    private func buildCalendarDayInNextMonth(endDateOfMonth: Date, diffDayFromEnd: Int) -> CalendarDay {
        guard let dateOfNextMonth = endDateOfMonth.addingComponentsOfDate(day: diffDayFromEnd) else {
            return CalendarDay()
        }
        
        return CalendarDay(
            date: dateOfNextMonth,
            isCurrentMonth: false
        )
    }
    
    /**
     ## 🔍 Event Logic: `hasEvents(from:)`

     The `EZCalendarItemViewModel` includes a specialized internal check to determine if a specific day should display an "event indicator" (like a dot or a highlight). This keeps the view logic simple: the view asks "Should I show a dot?", and the ViewModel answers with a `Bool`.

     ### 🛠 Method Breakdown

     ```swift
     private func hasEvents(from date: Date?) -> Bool {
         calendarMonth.events.contains(where: { $0.eventDate == date })
     }

     ```

     ### ⚙️ How it works

     1. **Source of Truth:** It looks inside the `calendarMonth.events` collection.
     2. **Date Matching:** It performs a search to see if any event in that month matches the `eventDate` of the day currently being rendered.
     3. **Safety:** It accepts an optional `Date?`. If the date is nil (e.g., a placeholder cell), it safely returns `false`.

     */
    private func hasEvents(from date: Date?) -> Bool {
        calendarMonth.events.contains(where: { $0.eventDate == date })
    }
}

        
