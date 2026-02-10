//
//  File.swift
//  EZCalendar
//
//  Created by wisanu on 29/9/2568 BE.
//

import Foundation

public class EZCalendarHelper {
    
    /**
     # 🛠️ Data Helper: `generateCalendarMonths`

     The `generateCalendarMonths` static method is a powerful utility designed to batch-create the data models required for a range-based calendar. It automates the process of calculating every month between two dates, ensuring you have a continuous timeline for your paging view.

     ## 🛠️ Method Signature

     ```swift
     public static func generateCalendarMonths(
         startDate: Date,
         endDate: Date,
         calendar: Calendar = .current,
         events: [CalendarEvent] = []
     ) -> [CalendarMonth]

     ```

     ### 📋 Parameters

     | Parameter | Default | Description |
     | --- | --- | --- |
     | `startDate` | (Required) | The point in time where the calendar begins. |
     | `endDate` | (Required) | The point in time where the calendar ends. |
     | `calendar` | `.current` | The calendar system (Gregorian, Buddhist, etc.) to use. |
     | `events` | `[]` | An optional array of events to be injected into the generated months. |

     ---

     ## 🚀 Usage Example

     Want to generate a calendar for the entire year of 2026? It’s as easy as this:

     ```swift
     let start = Date.from(year: 2026, month: 1, day: 1)!
     let end = Date.from(year: 2026, month: 12, day: 31)!

     // Generate 12 CalendarMonth objects in one go
     let myYear = EZCalendar.generateCalendarMonths(
         startDate: start,
         endDate: end,
         events: mySavedEvents
     )

     ```

     ---

     ## ⚙️ How it Works

     The logic follows a fail-safe iteration loop:

     1. **Normalization:** It starts by finding the `startOfMonth` for your given `startDate`. This ensures the loop starts cleanly on the 1st day.
     2. **The Loop:** It compares the current month pointer to the `endDate`.
     3. **Component Extraction:** For every iteration, it extracts the `.month` and `.year` integers.
     4. **Step Forward:** It uses your `.addingComponentsOfDate(month: 1)` helper to jump exactly one month ahead.
     5. **Safety Guard:** If any date calculation returns `nil` (rare edge cases), the loop breaks safely rather than crashing, returning all months processed up to that point.

     ---

     ## 💡 Pro-Tip: Integrating with Paging

     This helper is the perfect companion for `EZCalendarHorizontalPagingView`. You can call this in your `@State` initialization or inside `.onAppear` to populate the `calendarMonths` binding.

     ```swift
     .onAppear {
         if months.isEmpty {
             self.months = EZCalendar.generateCalendarMonths(
                 startDate: Date.now,
                 endDate: Date.now.addingTimeInterval(60*60*24*365) // 1 year from now
             )
         }
     }

     ```
     */
    public static func generateCalendarMonths(
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current,
        events: [CalendarEvent] = []
    ) -> [CalendarMonth] {
        var calendarMonths: [CalendarMonth] = []
        
        var currentFirstDateOfMonth = startDate.startOfMonth
        
        while currentFirstDateOfMonth <= endDate {
            
            let calendarComponents = calendar.dateComponents([.month, .year], from: currentFirstDateOfMonth)
            
            guard let year = calendarComponents.year, let month = calendarComponents.month else {
                break
            }
            
            calendarMonths.append(
                CalendarMonth(month: month, year: year)
            )
            
            guard let nextFirstDateOfMonth = currentFirstDateOfMonth.addingComponentsOfDate(month: 1) else {
                break
            }
            
            currentFirstDateOfMonth = nextFirstDateOfMonth
        }
        
        return calendarMonths
    }
    
    
}
