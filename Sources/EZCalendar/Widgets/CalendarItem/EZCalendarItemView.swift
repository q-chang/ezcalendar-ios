//
//  EZCalendarItemView.swift
//  EZCalendar
//
//  Created by Wisanu Paunglumjeak on 25/12/2567 BE.
//

import SwiftUI

/**
 # 🖼️ Component: `EZCalendarItemView`

 `EZCalendarItemView` is the primary container for displaying a month's grid. It utilizes a `LazyVGrid` to ensure efficient rendering and provides a generic `@ViewBuilder` so you can customize the appearance of individual day cells.

 ## 🛠️ View Configuration

 ### Initialization

 To create a calendar month, pass in the month data, the calendar configuration, and a custom view for the days.

 ```swift
 public init(
     _ calendarMonth: CalendarMonth,
     calendar: Calendar,
     @ViewBuilder dayItemViewContent: @escaping (CalendarDay) -> DayItemView
 )

 ```

 ### Key Features

 * **Adaptive Grid:** Automatically sets up a 7-column layout using `GridItem(.flexible())`.
 * **Flat Data Mapping:** It flattens the `calendarWeeks` into a single array for the `LazyVGrid` while maintaining the correct visual order.
 * **Custom Styling:** Use the `.gridLineColor()` modifier to add a border or grid lines between cells.

 ---

 ## 🚀 Usage

 ### Simple Implementation

 Here’s how you can use `EZCalendarItemView` to build a clean, modern calendar:

 ```swift
 EZCalendarItemView(currentMonth, calendar: .current) { day in
     VStack {
         Text("\(day.dayNumber)")
             .foregroundColor(day.isCurrentMonth ? .primary : .secondary)
         
         if day.hasEvents {
             Circle()
                 .fill(.blue)
                 .frame(width: 4, height: 4)
         }
     }
     .frame(height: 50)
     .background(Color.white)
 }
 .gridLineColor(.gray.opacity(0.2)) // Optional: Add grid lines

 ```

 ---

 ## 🎨 Modifiers

 ### `.gridLineColor(Color?)`

 This modifier allows you to easily toggle the "grid" look.

 * **If `nil**`: The grid renders without any background or borders.
 * **If a `Color` is provided**: The grid adds a 1pt padding and sets the background color, creating a "grid line" effect between cells (assuming your cells have their own background color).

 ---

 ## ⚙️ Layout Architecture

 The view handles the layout complexity so you don't have to:

 1. **Columns:** Defined as `Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)`.
 2. **Spacing:** Uses a standard `1pt` spacing to allow background colors to peek through as grid lines.
 3. **ViewModel Integration:** It initializes its own `EZCalendarItemViewModel` internally, acting as the bridge between raw data and the screen.

 ```swift
 let gridView = LazyVGrid(columns: columns, spacing: 1) {
     ForEach(viewModel.calendarWeeks.flatMap { $0.calendarDays }, id: \.self) { calendarDay in
         dayItemViewContent(calendarDay)
     }
 }

 ```
 */
public struct EZCalendarItemView<DayItemView>: View where DayItemView: View {
    
    @ObservedObject var viewModel: EZCalendarItemViewModel
    
    var dayItemViewContent: (CalendarDay) -> DayItemView
    private var gridLineColor: Color? = nil
    
    public init(
        _ calendarMonth: CalendarMonth,
        calendar: Calendar,
        @ViewBuilder dayItemViewContent: @escaping (CalendarDay) -> DayItemView
    ) {
        self.viewModel = EZCalendarItemViewModel(
            calendarMonth: calendarMonth,
            calendar: calendar
        )
        self.dayItemViewContent = dayItemViewContent
    }
    
    public var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
        
        let gridView = LazyVGrid(columns: columns, spacing: 1) {
            ForEach(viewModel.calendarWeeks.flatMap { $0.calendarDays }, id: \.self) { calendarDay in
                dayItemViewContent(calendarDay)
            }
        }
        
        if self.gridLineColor == nil {
            gridView
        } else {
            gridView
                .padding(1)
                .background(self.gridLineColor)
        }
    }
    
    func gridLineColor(_ color: Color?) -> Self {
        guard let color else {
            return self
        }
        
        var newView = self
        newView.gridLineColor = color
        return newView
    }
}
