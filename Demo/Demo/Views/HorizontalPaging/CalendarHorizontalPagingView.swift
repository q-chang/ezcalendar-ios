//
//  CalendarHorizontalPagingView.swift
//  Demo
//
//  Created by Wisanu Paunglumjeak on 12/1/2568 BE.
//

import SwiftUI
import EZCalendar

/**
 # 🚀 Full Demo: Integrated Paging Calendar

 The `CalendarHorizontalPagingView` (Demo) demonstrates the library's full potential. It features manual navigation buttons, localized date headers, and reactive event updates using the `EZCalendarHorizontalPagingView` as its core engine.

 ## ✨ Key Demo Features

 ### 1. Smart Navigation Controls

 The demo includes "Previous" and "Next" buttons that interact directly with the ViewModel's `currentMonth`.

 * **Boundary Protection:** Buttons are automatically **disabled** when the user reaches the `startDate` or `endDate`, preventing invalid date navigation.
 * **Animated Transitions:** Swapping the `currentMonth` programmatically triggers the internal snapping animation of the paging view.

 ### 2. Custom Styling via ViewBuilders

 This demo highlights the power of the generic `@ViewBuilder` approach:

 * **Red Weekdays:** The header titles are styled with `Color.red`.
 * **Blue Event Indicators:** Instead of just a dot, this demo uses a blue background highlight:
 ```swift
 .background(calendarDay.hasEvents ? Color.blue : Color.clear)

 ```



 ### 3. Dynamic Data Syncing

 Using `.onChange(of: viewModel.currentMonth)`, the demo can trigger side effects (like fetching new events from an API or database) whenever the visible month changes.

 ---

 ## 🛠️ Implementation Breakdown

 ### The Header Logic

 The header uses a simple `HStack` to display the month and year, localized automatically via the ViewModel’s calendar settings.

 ```swift
 Text(viewModel.currentMonth.toString(dateFormat: "MMMM yyyy", locale: viewModel.calendar.locale!))

 ```

 ### The Paging View Integration

 The `EZCalendarHorizontalPagingView` is configured with `weekdayScrollable(true)`, meaning the red weekday headers will slide horizontally along with the dates for a consistent "page" feel.

 ---

 ## 🏗️ Architecture Summary

 | Component | Responsibility |
 | --- | --- |
 | **`CalendarHorizontalPaggingViewModel`** | Manages `Date` ranges, fetches events, and validates boundaries. |
 | **`EZCalendarHorizontalPagingView`** | Handles the complex `ScrollView` logic and snapping behavior. |
 | **`GeometryReader`** | Ensures the grid remains perfectly proportional to the screen width. |

 ---

 ## 💡 Usage Tip: Adaptive Layouts

 By using `proxy.size.width / 7`, this calendar remains perfectly responsive. Whether it's on a small iPhone SE or a large iPad, the cells will always maintain their grid alignment without manual padding adjustments.
 */
struct CalendarHorizontalPagingView: View {
    @StateObject var viewModel: CalendarHorizontalPaggingViewModel
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    
                    HStack {
                        Button("Previous") {
                            guard let date = viewModel.currentMonth.addingComponentsOfDate(month: -1),
                                  viewModel.isDateGreaterThanOrEqualStartDate(date) else {
                                return
                            }
                            viewModel.currentMonth = date
                        }
                        .disabled(
                            !viewModel.isDateGreaterThanOrEqualStartDate(
                                viewModel.currentMonth.addingComponentsOfDate(month: -1)!
                            )
                        )
                        .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        Text(viewModel.currentMonth.toString(dateFormat: "MMMM yyyy", locale: viewModel.calendar.locale!))
                        
                        Spacer()
                        
                        Button("Next") {
                            guard let date = viewModel.currentMonth.addingComponentsOfDate(month: 1),
                                  viewModel.isDateLessThanOrEqualEndDate(date) else {
                                return
                            }
                            viewModel.currentMonth = date
                        }
                        .disabled(
                            !viewModel.isDateLessThanOrEqualEndDate(
                                viewModel.currentMonth.addingComponentsOfDate(month: 1)!
                            )
                        )
                        .frame(width: 100, alignment: .trailing)
                    }
                    .bold()
                    .padding(16)
                    
                    EZCalendarHorizontalPagingView(
                        withCalendar: viewModel.calendar,
                        weekDayTitles: viewModel.weekdayTitles,
                        currentMonth: $viewModel.currentMonth,
                        calendarMonths: $viewModel.calendarMonths
                    ) { weekdayTitle in
                        Text(weekdayTitle)
                            .foregroundStyle(Color.red)
                            .bold()
                            .frame(
                                width: proxy.size.width / 7,
                                height: 24
                            )
                    } dayItemViewContent: { calendarDay in
                        
                        Text(" \(calendarDay.date?.get(.day) ?? 0) ")
                            .foregroundStyle(
                                calendarDay.isCurrentMonth
                                ? Color.black
                                : Color.gray
                            )
                            .padding(4)
                            .background(calendarDay.hasEvents ? Color.blue : Color.clear)
                            .frame(
                                width: proxy.size.width / 7,
                                height: proxy.size.width / 7
                            )
                    }
                    .weekdayScrollable(true)
                }
            }
        }
        .onChange(of: viewModel.currentMonth) { _, monthDate in
            viewModel.updateEvents(monthDate)
        }
    }
}

#Preview {
    CalendarHorizontalPagingView(
        viewModel: CalendarHorizontalPaggingViewModel(
            withCalendar: {
                var calendar: Calendar = .init(identifier: .buddhist)
                calendar.locale = Locale(identifier: "th-TH")
                return calendar
            }()
        )
    )
}
