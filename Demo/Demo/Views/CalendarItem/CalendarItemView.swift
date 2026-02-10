//
//  CalendarItemView.swift
//  Demo
//
//  Created by Wisanu Paunglumjeak on 12/1/2568 BE.
//

import SwiftUI
import EZCalendar

/**
 # 📱 Demo: Vertical Scrolling Calendar

 While the library includes a native paging view, you can easily compose a custom vertical scrolling experience using `ScrollView` and `GeometryReader`. This is ideal for "infinite scroll" layouts or year-at-a-glance views.

 ## 🛠️ Implementation Strategy

 In this demo, we use `GeometryReader` to dynamically calculate the width of each calendar day, ensuring that the 7-column grid perfectly fits any screen size.

 ### The Code

 ```swift
 struct CalendarItemView: View {
     var body: some View {
         GeometryReader { proxy in
             ScrollView {
                 VStack(spacing: 0) {
                     // Render September 2024
                     EZCalendarItemView(
                         CalendarMonth(month: 9, year: 2024),
                         calendar: .init(identifier: .gregorian)
                     ) { calendarDay in
                         DayCell(day: calendarDay, size: proxy.size.width / 7)
                     }

                     DividerLine()

                     // Render October 2024
                     EZCalendarItemView(
                         CalendarMonth(month: 10, year: 2024),
                         calendar: .init(identifier: .gregorian)
                     ) { calendarDay in
                         DayCell(day: calendarDay, size: proxy.size.width / 7)
                     }
                 }
             }
         }
     }
 }

 ```

 ---

 ## 🎨 Design Key Points

 ### 1. Adaptive Sizing

 By dividing `proxy.size.width` by **7**, you ensure that each cell is a perfect square that spans the full width of the device.

 ```swift
 .frame(width: proxy.size.width / 7, height: proxy.size.width / 7)

 ```

 ### 2. Contextual Styling

 The demo uses a simple conditional to differentiate between dates in the current month and the "padding" dates from adjacent months:

 * **Current Month:** `Color.black`
 * **Outside Month:** `Color.gray`

 ### 3. Separation of Concerns

 Using `Rectangle()` or `Divider()` between `EZCalendarItemView` instances allows you to clearly define the boundary between different months in a long list.

 ---

 ## ✅ Best Practices from this Demo

 * **Lazy Loading:** For very long lists (e.g., 24 months), wrap the months in a `LazyVStack` inside the `ScrollView` to maintain high performance.
 * **Geometry Tracking:** `GeometryReader` is excellent for ensuring the calendar remains responsive on both iPhone and iPad layouts.
 * **Reusable Cells:** Extracting the `Text(...)` logic into a separate `DayCell` view will keep your main layout much cleaner.
 */
struct CalendarItemView: View {
    var body: some View {
        VStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        
                        EZCalendarItemView(
                            CalendarMonth(month: 9, year: 2024),
                            calendar: .init(identifier: .gregorian)
                        ) { calendarDay in
                            Text(" \(calendarDay.date?.get(.day) ?? 0) ")
                                .foregroundStyle(
                                    calendarDay.isCurrentMonth
                                    ? Color.black
                                    : Color.gray
                                )
                                .frame(
                                    width: proxy.size.width / 7,
                                    height: proxy.size.width / 7
                                )
                        }
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                            .padding(16)
                        
                        EZCalendarItemView(
                            CalendarMonth(month: 10, year: 2024),
                            calendar: .init(identifier: .gregorian)
                        ) { calendarDay in
                            Text(" \(calendarDay.date?.get(.day) ?? 0) ")
                                .foregroundStyle(
                                    calendarDay.isCurrentMonth
                                    ? Color.black
                                    : Color.gray
                                )
                                .frame(
                                    width: proxy.size.width / 7,
                                    height: proxy.size.width / 7
                                )
                        }
                        
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                            .padding(16)
                        
                        EZCalendarItemView(
                            CalendarMonth(month: 11, year: 2024),
                            calendar: .init(identifier: .gregorian)
                        ) { calendarDay in
                            Text(" \(calendarDay.date?.get(.day) ?? 0) ")
                                .foregroundStyle(
                                    calendarDay.isCurrentMonth
                                    ? Color.black
                                    : Color.gray
                                )
                                .frame(
                                    width: proxy.size.width / 7,
                                    height: proxy.size.width / 7
                                )
                        }
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 1)
                            .padding(16)
                        
                        EZCalendarItemView(
                            CalendarMonth(month: 12, year: 2024),
                            calendar: .init(identifier: .gregorian)
                        ) { calendarDay in
                            Text(" \(calendarDay.date?.get(.day) ?? 0) ")
                                .foregroundStyle(
                                    calendarDay.isCurrentMonth
                                    ? Color.black
                                    : Color.gray
                                )
                                .frame(
                                    width: proxy.size.width / 7,
                                    height: proxy.size.width / 7
                                )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CalendarItemView()
}
