# 📅 EZCalendar

**EZCalendar** is a lightweight, logic-first calendar library for **SwiftUI**. It handles the heavy lifting of date calculations, grid alignment, and horizontal paging, while giving you 100% declarative control over the UI.

## ✨ Features

* **Zero Layout Constraints:** You provide the views for days and headers; EZCalendar provides the grid logic.
* **Native Paging:** Smooth, view-aligned horizontal scrolling using the latest SwiftUI `scrollTargetBehavior`.
* **Logic-First:** Decoupled ViewModel handles "leading" and "trailing" days from adjacent months automatically.
* **Event Ready:** Built-in support for event indicators and dynamic event fetching.
* **Localization:** Fully supports any `Locale` or `Calendar` system (Gregorian, Buddhist, etc.).

---

## 🏗️ Architecture

The library follows a clean MVVM pattern, allowing you to use the raw logic or the pre-built UI components.

1. **The Logic (`EZCalendarItemViewModel`)**: Calculates the 7x5 or 7x6 grid, including padding days.
2. **The Grid (`EZCalendarItemView`)**: A specialized `LazyVGrid` that renders a single month.
3. **The Paging Engine (`EZCalendarHorizontalPagingView`)**: A horizontal scroller that manages month-to-month transitions.

---

## 🚀 Quick Start (Paging Demo)

To create a fully interactive, paging calendar with navigation buttons, follow this pattern:

### 1. Setup the ViewModel

```swift
class MyCalendarViewModel: ObservableObject {
    @Published var currentMonth = Date()
    @Published var calendarMonths: [CalendarMonth] = []

    init() {
        // Generate months for the next 2 years
        self.calendarMonths = EZCalendar.generateCalendarMonths(
            startDate: .now,
            endDate: .now.addingTimeInterval(60*60*24*730)
        )
    }
}

```

### 2. Implementation in View

```swift
struct CalendarView: View {
    @StateObject var viewModel = MyCalendarViewModel()

    var body: some View {
        GeometryReader { proxy in
            EZCalendarHorizontalPagingView(
                withCalendar: .current,
                currentMonth: $viewModel.currentMonth,
                calendarMonths: $viewModel.calendarMonths,
                weekdayItemViewContent: { title in
                    Text(title).bold().foregroundColor(.red)
                },
                dayItemViewContent: { day in
                    VStack {
                        Text("\(day.dayNumber)")
                            .foregroundColor(day.isCurrentMonth ? .primary : .secondary)
                        
                        if day.hasEvents {
                            Circle().fill(.blue).frame(width: 4, height: 4)
                        }
                    }
                    .frame(width: proxy.size.width / 7, height: proxy.size.width / 7)
                }
            )
            .gridLineColor(.gray.opacity(0.1))
        }
    }
}

```

---

## 🛠️ Components API

### `EZCalendarHorizontalPagingView`

The high-level component for swiping between months.

| Property | Description |
| --- | --- |
| `currentMonth` | A binding to the date currently displayed. |
| `weekdayScrollable` | If `true`, the day headers (Mon, Tue...) scroll with the month. |
| `gridLineColor` | Optional modifier to add separators between date cells. |

### `EZCalendarItemView`

The low-level grid component. Perfect for vertical scrolling lists.

```swift
EZCalendarItemView(monthData, calendar: .current) { day in
    // Your custom Day View
}

```

### `EZCalendar.generateCalendarMonths`

Static helper to create the data source for your calendar.

```swift
let months = EZCalendar.generateCalendarMonths(
    startDate: dateA, 
    endDate: dateB, 
    events: myEvents
)

```

---

## 🎨 Customization

### Vertical Scrolling

Because `EZCalendarItemView` is a standard SwiftUI `View`, you can stack them in a vertical `ScrollView` for a different UX:

```swift
ScrollView {
    ForEach(viewModel.calendarMonths) { month in
        EZCalendarItemView(month, calendar: .current) { day in
            Text("\(day.dayNumber)")
        }
        Divider()
    }
}

```

---

## ⚙️ Requirements

* **iOS 17.0+** / **macOS 14.0+**
* **Swift 5.9+**
* **Xcode 15.0+**
