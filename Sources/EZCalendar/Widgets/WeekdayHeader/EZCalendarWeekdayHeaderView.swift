//
//  EZCalendarWeekdayHeaderView.swift
//  EZCalendar
//
//  Created by Wisanu Paunglumjeak on 25/12/2567 BE.
//

import SwiftUI

/**
 # 📅 EZCalendar: Weekday Header

 The `EZCalendarWeekdayHeaderView` is a flexible SwiftUI component designed to display the days of the week (e.g., Sun, Mon, Tue). It supports automatic localization or custom titles and uses a generic `ViewBuilder` so you can style the header items exactly how you want.

 ## 🛠 Component: `EZCalendarWeekdayHeaderView`

 ### Initialization

 You can initialize the header by providing a locale (for automatic names) or your own array of strings.

 | Parameter | Type | Description |
 | --- | --- | --- |
 | `weekDayTitles` | `[String]?` | Optional. Provide custom titles. If `nil`, it uses localized symbols. |
 | `locale` | `Locale` | Used to fetch short weekday symbols (e.g., "Mon", "Tue"). |
 | `weekdayItemViewContent` | `@ViewBuilder` | A closure that returns the view for each weekday title. |

 ---

 ## 🚀 Usage Examples

 ### 1. Basic Localized Header

 The easiest way to use it is to let the library handle the naming based on the user's system locale.

 ```swift
 EZCalendarWeekdayHeaderView(locale: Locale(identifier: "en_US")) { title in
     Text(title)
         .font(.caption)
         .fontWeight(.bold)
         .frame(maxWidth: .infinity)
         .foregroundColor(.secondary)
 }

 ```

 ### 2. Custom Titles & Styling

 If you want to use specific names or a different style (like a circular background), just pass the `weekDayTitles`.

 ```swift
 let myTitles = ["S", "M", "T", "W", "T", "F", "S"]

 EZCalendarWeekdayHeaderView(weekDayTitles: myTitles, locale: .current) { title in
     VStack {
         Text(title)
             .padding(8)
             .background(Color.blue.opacity(0.1))
             .clipShape(Circle())
     }
     .frame(maxWidth: .infinity)
 }

 ```

 ---

 ## 🏗 Implementation Details

 The view utilizes a horizontal stack (`HStack`) with zero spacing to ensure equal distribution across the calendar width. By using a generic `WeekdayItemView`, **EZCalendar** ensures that the parent layout remains decoupled from the specific design of the header.

 ```swift
 // Internal layout structure
 public var body: some View {
     HStack(spacing: 0) {
         ForEach(weekDayTitles, id: \.self) { title in
             weekdayItemViewContent(title)
         }
     }
 }

 ```

 ---

 **That’s a solid header component! Would you like me to help you write the documentation for the main Month Grid or the Date Calculation logic next?**
 */
public struct EZCalendarWeekdayHeaderView<WeekdayItemView>: View where WeekdayItemView: View {
    
    var weekDayTitles: [String] = []
    var weekdayItemViewContent: (String) -> WeekdayItemView
    
    init(
        weekDayTitles: [String]? = nil,
        locale: Locale,
        @ViewBuilder weekdayItemViewContent: @escaping (String) -> WeekdayItemView
    ) {
        if let weekDayTitles {
            self.weekDayTitles = weekDayTitles
        } else {
            let formatter = DateFormatter()
            formatter.locale = locale
            self.weekDayTitles = formatter.shortWeekdaySymbols
        }
        self.weekdayItemViewContent = weekdayItemViewContent
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDayTitles, id: \.self) { title in
                weekdayItemViewContent(title)
            }
        }
    }
}
