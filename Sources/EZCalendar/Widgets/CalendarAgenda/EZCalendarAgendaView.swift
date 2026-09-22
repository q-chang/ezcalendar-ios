//
//  EZCalendarAgendaView.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI

/**
 # 📆 Component: `EZCalendarAgendaView`

 A collapsible calendar stacked on a continuous, date-grouped event list, with
 the two kept in sync in both directions.

 ```
 ┌─────────────────────────────┐
 │  ‹   July 2569   ›          │  titleViewContent      (caller)
 │  Su Mo Tu We Th Fr Sa       │  weekdayItemViewContent (caller)
 │  30  1  2 [3] 4  5  6       │  dayItemViewContent     (caller)
 │   7  8  9 10 11 12 13       │  … collapses to one row
 ├─────────────────────────────┤
 │            ▭                │  handleViewContent      (caller)
 │  Wednesday, 3 July 2569     │  listHeaderViewContent  (caller, sticky)
 │    09:00  Install job       │  eventItemViewContent   (caller)
 │    13:00  Install job       │
 │  Thursday, 4 July 2569      │
 └─────────────────────────────┘
 ```

 Like everything else in this package, it renders **no styling of its own**. It
 owns structure, state and gesture math; all seven visual slots are yours.

 ---

 ## 🚀 Usage

 ```swift
 @State private var mode: EZCalendarAgendaMode = .monthly
 @State private var selectedDate = Date()
 @State private var months: [CalendarMonth] = []

 EZCalendarAgendaView(
     withCalendar: calendar,
     mode: $mode,
     selectedDate: $selectedDate,
     calendarMonths: $months,
     events: jobs,                        // your own type
     eventDate: { $0.scheduledAt },       // how to file it under a day
     titleViewContent: { context in
         HStack {
             Button(action: context.pageBackward) { Image(systemName: "chevron.left") }
             Text(monthFormatter.string(from: context.date))
             Button(action: context.pageForward) { Image(systemName: "chevron.right") }
         }
     },
     weekdayItemViewContent: { title in
         Text(title).frame(maxWidth: .infinity)
     },
     dayItemViewContent: { context in
         DayCell(context)                 // context.isSelected, .isToday, .hasEvents
     },
     listHeaderViewContent: { section in
         HStack {
             Text(headerFormatter.string(from: section.date))
             Spacer()
             Text("\(section.events.count)")
         }
     },
     eventItemViewContent: { job in
         JobRow(job)
     },
     emptyDayViewContent: { _ in
         Text("No jobs").frame(maxWidth: .infinity, alignment: .leading)
     },
     handleViewContent: {
         Capsule().frame(width: 36, height: 5)
     }
 )
 .gridLineColor(.secondary.opacity(0.1))
 .collapseThreshold(78)
 ```

 A shorter initializer drops `titleViewContent`, `emptyDayViewContent` and
 `handleViewContent` when you do not need them.

 ---

 ## ⚙️ Parameters

 | Parameter | Description |
 | --- | --- |
 | `withCalendar` | Calendar for every date computation. Its `locale` names the weekdays. |
 | `weekDayTitles` | Optional override for the weekday header strings. |
 | `mode` | `@Binding` — `.monthly` or `.weekly`. Read *and* written by the view. |
 | `selectedDate` | `@Binding` — the selected day, normalised to the start of the day. |
 | `calendarMonths` | `@Binding` — the paged range, exactly as `EZCalendarHorizontalPagingView` takes it. |
 | `events` | Your events, any type that is `Identifiable`. |
 | `eventDate` | Which day each event belongs to. Matched by *day*, not by instant. |

 ### Modifiers

 * **`.gridLineColor(_:)`** — background behind the grid, showing through the
   1pt row and column gaps as grid lines.
 * **`.collapseThreshold(_:)`** — how far the handle must be dragged, on
   release, to switch modes. Default `78`.
 * **`.collapseVelocityThreshold(_:)`** — how fast it must be flicked to switch
   regardless of distance, in points per second. Default `350`.
 * **`.collapseAnimation(_:)`** — how a released gesture settles. Default
   `.easeOut(duration: 0.3)`.

 ---

 ## 🔄 The four interactions

 ### 1. Tap a day → the list scrolls, and the calendar collapses

 The tapped day's sticky header animates to the top of the list. In `.monthly`
 the tap *also* snaps the calendar to `.weekly`, so the list gets its full height
 without the user having to drag for it.

 ### 2. Scroll the list → the calendar follows

 Whichever sticky header is pinned at the top is the day the calendar selects,
 paging itself to a new month or week if the list has scrolled that far.

 ### 3. Drag the grab handle → the calendar collapses and expands

 Drag the handle up out of `.monthly` to collapse, down out of `.weekly` to
 expand. The calendar tracks the finger point-for-point on the way — non-selected
 weeks fading as the grid closes over them — and nothing is committed until the
 finger lifts:

 | On release | Result |
 | --- | --- |
 | dragged at least `collapseThreshold` the right way | animates the rest of the way and switches |
 | flicked at least `collapseVelocityThreshold` the right way | switches too, however short the drag |
 | neither, or the wrong way | animates back to where it started |

 So a quick flick switches without dragging the calendar shut by hand, and a
 long exploratory drag can still be abandoned by reversing it before letting go.

 **The handle is the only surface that does this.** Scrolling the event list only
 ever scrolls the list, in either direction, over-scroll included.

 ### 4. Swipe the calendar → the page and the selection change together

 | Mode | Swipe lands on | Selection becomes |
 | --- | --- | --- |
 | `.monthly` | a new month | today if it is this month, otherwise the 1st |
 | `.weekly` | a new week | today if it is this week, otherwise the week's first day |

 `context.pageForward()` / `context.pageBackward()` do the same thing from your
 title bar, and assigning `selectedDate` does it programmatically.

 ---

 ## ⚠️ Notes for callers

 * **Use `context.hasEvents`, not `context.day.hasEvents`.** This view buckets
   your `events` by *day*; `CalendarDay.hasEvents` needs an exact `Date` match
   and is always `false` on padding days. See `EZCalendarDayContext`.
 * **Events outside `calendarMonths` still appear in the list.** The list's range
   is the months unioned with your event dates, so nothing is silently dropped —
   though the calendar cannot page to a month you did not supply.
 * **The grid is Sunday-first**, regardless of `calendar.firstWeekday`. That is a
   package-wide behaviour shared with `EZCalendarItemView`, and the weekday
   header is Sunday-indexed to match.
 * **`selectedDate` is normalised** to the start of its day, in the view's
   calendar. Assigning `14:30` reads back as `00:00` of the same day.
 */
public struct EZCalendarAgendaView<
    Event,
    TitleView,
    WeekdayItemView,
    DayItemView,
    ListHeaderView,
    EventItemView,
    EmptyDayView,
    HandleView
>: View where
    Event: Identifiable,
    TitleView: View,
    WeekdayItemView: View,
    DayItemView: View,
    ListHeaderView: View,
    EventItemView: View,
    EmptyDayView: View,
    HandleView: View
{

    // MARK: - Stored configuration

    private let calendar: Calendar
    private let locale: Locale
    private let weekDayTitles: [String]?

    @Binding private var mode: EZCalendarAgendaMode
    @Binding private var selectedDate: Date
    @Binding private var calendarMonths: [CalendarMonth]

    private let events: [Event]
    private let eventDate: (Event) -> Date

    private let titleViewContent: (EZCalendarAgendaTitleContext) -> TitleView
    private let weekdayItemViewContent: (String) -> WeekdayItemView
    private let dayItemViewContent: (EZCalendarDayContext) -> DayItemView
    private let listHeaderViewContent: (EZCalendarAgendaSection<Event>) -> ListHeaderView
    private let eventItemViewContent: (Event) -> EventItemView
    private let emptyDayViewContent: (Date) -> EmptyDayView
    private let handleViewContent: () -> HandleView

    // MARK: - State

    @StateObject private var viewModel: EZCalendarAgendaViewModel

    /// Derived list data. Held in `@State` rather than recomputed in `body`,
    /// because `body` re-runs on every frame of a collapse and rebuilding a
    /// year of sections 60 times a second is not free.
    @State private var sections: [EZCalendarAgendaSection<Event>] = []
    @State private var daysWithEvents: Set<String> = []

    // MARK: - Modifier state

    private var gridLineColor: Color?
    private var collapseThreshold: Double = 78
    private var collapseVelocityThreshold: Double = 350
    private var collapseAnimation: Animation = .easeOut(duration: 0.3)
    private var collapseOnDaySelection = true

    public init(
        withCalendar calendar: Calendar,
        weekDayTitles: [String]? = nil,
        mode: Binding<EZCalendarAgendaMode>,
        selectedDate: Binding<Date>,
        calendarMonths: Binding<[CalendarMonth]>,
        events: [Event],
        eventDate: @escaping (Event) -> Date,
        @ViewBuilder titleViewContent: @escaping (EZCalendarAgendaTitleContext) -> TitleView,
        @ViewBuilder weekdayItemViewContent: @escaping (String) -> WeekdayItemView,
        @ViewBuilder dayItemViewContent: @escaping (EZCalendarDayContext) -> DayItemView,
        @ViewBuilder listHeaderViewContent: @escaping (EZCalendarAgendaSection<Event>) -> ListHeaderView,
        @ViewBuilder eventItemViewContent: @escaping (Event) -> EventItemView,
        @ViewBuilder emptyDayViewContent: @escaping (Date) -> EmptyDayView,
        @ViewBuilder handleViewContent: @escaping () -> HandleView
    ) {
        self.calendar = calendar
        self.locale = calendar.locale ?? Locale.current
        self.weekDayTitles = weekDayTitles
        self._mode = mode
        self._selectedDate = selectedDate
        self._calendarMonths = calendarMonths
        self.events = events
        self.eventDate = eventDate
        self.titleViewContent = titleViewContent
        self.weekdayItemViewContent = weekdayItemViewContent
        self.dayItemViewContent = dayItemViewContent
        self.listHeaderViewContent = listHeaderViewContent
        self.eventItemViewContent = eventItemViewContent
        self.emptyDayViewContent = emptyDayViewContent
        self.handleViewContent = handleViewContent

        self._viewModel = StateObject(
            wrappedValue: EZCalendarAgendaViewModel(
                calendar: calendar,
                mode: mode.wrappedValue,
                selection: selectedDate.wrappedValue
            )
        )
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            AgendaCalendarView(
                viewModel: viewModel,
                weekDayTitles: weekDayTitles,
                locale: locale,
                gridLineColor: gridLineColor,
                titleViewContent: titleViewContent,
                weekdayItemViewContent: weekdayItemViewContent,
                dayItemViewContent: dayCell
            )

            AgendaListView(
                viewModel: viewModel,
                sections: sections,
                listHeaderViewContent: listHeaderViewContent,
                eventItemViewContent: eventItemViewContent,
                emptyDayViewContent: emptyDayViewContent,
                handleViewContent: handleViewContent
            )
        }
        .onAppear(perform: start)
        .onChange(of: calendarMonths) { _, months in
            viewModel.rebuildPages(from: months)
            rebuildSections()
        }
        .onChange(of: eventsFingerprint) { _, _ in
            rebuildSections()
        }
        // MARK: Binding mirrors
        //
        // The view model is the source of truth; these four keep the caller's
        // bindings and the view model in step without either one looping. Each
        // guard is what breaks the cycle: assigning a value that is already
        // there does not fire `onChange` again.
        .onChange(of: viewModel.mode) { _, newMode in
            if mode != newMode { mode = newMode }
            viewModel.modeChanged()
        }
        .onChange(of: mode) { _, newMode in
            if viewModel.mode != newMode { viewModel.mode = newMode }
        }
        .onChange(of: viewModel.selection) { _, newSelection in
            if selectedDate != newSelection { selectedDate = newSelection }
            viewModel.selectionChanged()
        }
        .onChange(of: selectedDate) { _, newDate in
            let normalised = calendar.startOfDay(for: newDate)
            if viewModel.selection != normalised { viewModel.selection = normalised }
        }
    }

    // MARK: - Day cells

    /// Wraps the caller's cell with the selection tap.
    ///
    /// `contentShape` makes the whole cell tappable even where the caller drew
    /// nothing — without it, the gaps in a sparse cell would swallow taps.
    private func dayCell(for day: CalendarDay) -> some View {
        dayItemViewContent(context(for: day))
            .contentShape(Rectangle())
            .onTapGesture {
                guard let date = day.date else { return }
                viewModel.selectDay(date, collapseOnSelection: collapseOnDaySelection)
            }
    }

    private func context(for day: CalendarDay) -> EZCalendarDayContext {
        guard let date = day.date else {
            return EZCalendarDayContext(day: day, isSelected: false, isToday: false, hasEvents: false)
        }

        return EZCalendarDayContext(
            day: day,
            isSelected: calendar.isDate(date, inSameDayAs: viewModel.selection),
            isToday: calendar.isDateInToday(date),
            // Same-day matching against the agenda's own events, so padding days
            // and events stamped at a real time of day both work.
            hasEvents: daysWithEvents.contains(EZCalendarAgendaLogic.dayID(for: date, calendar: calendar))
        )
    }

    // MARK: - Derived data

    /// Cheap change signal for `events`: order-sensitive hash of each event's
    /// identity and day. Hashing beats holding the array in `@State` because
    /// `Event` is the caller's type and need not be `Equatable`.
    private var eventsFingerprint: Int {
        var hasher = Hasher()

        for event in events {
            hasher.combine(event.id)
            hasher.combine(eventDate(event))
        }

        return hasher.finalize()
    }

    private func rebuildSections() {
        let index = EZCalendarAgendaLogic.eventIndex(
            events: events,
            eventDate: eventDate,
            monthPages: viewModel.monthPages,
            calendar: calendar
        )

        sections = index.sections
        daysWithEvents = index.daysWithEvents

        // The view model turns a reported header id back into a day with this.
        viewModel.sectionDates = Dictionary(
            index.sections.map { ($0.id, $0.date) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func start() {
        viewModel.collapseThreshold = collapseThreshold
        viewModel.collapseVelocityThreshold = collapseVelocityThreshold
        viewModel.collapseAnimation = collapseAnimation

        viewModel.rebuildPages(from: calendarMonths)
        rebuildSections()
        viewModel.primePagers(for: viewModel.selection)

        // Push the normalised selection back out, so the caller's binding and
        // the view agree from the first frame.
        if selectedDate != viewModel.selection {
            selectedDate = viewModel.selection
        }

        // One run loop later: the list has to exist before it can be scrolled.
        DispatchQueue.main.async {
            viewModel.selectionChanged()
        }
    }

    // MARK: - Modifiers

    /// Colour showing through the grid's 1pt gaps as grid lines. `nil` leaves
    /// the grid unstyled.
    public func gridLineColor(_ color: Color?) -> Self {
        guard let color else { return self }

        var view = self
        view.gridLineColor = color
        return view
    }

    /// How far the grab handle must be dragged, on release, to switch modes.
    /// A drag that stops short of this springs back — unless it was fast enough
    /// to clear `collapseVelocityThreshold(_:)`. Default `78`.
    ///
    /// This is only the commit decision. While the finger is down the calendar
    /// tracks it against the grid's own collapsible height, so the two distances
    /// are deliberately independent.
    public func collapseThreshold(_ points: CGFloat) -> Self {
        guard points > 0 else { return self }

        var view = self
        view.collapseThreshold = Double(points)
        return view
    }

    /// How fast the grab handle must be flicked, in points per second, to switch
    /// modes regardless of how far it travelled. Default `350`.
    ///
    /// Speed is additive: it can commit a drag that was too short, never veto
    /// one that was long enough. Pass `0` to require the distance every time.
    public func collapseVelocityThreshold(_ pointsPerSecond: CGFloat) -> Self {
        guard pointsPerSecond >= 0 else { return self }

        var view = self
        view.collapseVelocityThreshold = Double(pointsPerSecond)
        return view
    }

    /// How a released gesture, or a programmatic `mode` change, settles.
    public func collapseAnimation(_ animation: Animation) -> Self {
        var view = self
        view.collapseAnimation = animation
        return view
    }

    /// Whether selecting a day in the monthly calendar collapses it to weekly mode.
    /// Enabled by default to preserve the original interaction.
    public func collapseOnDaySelection(_ enabled: Bool) -> Self {
        var view = self
        view.collapseOnDaySelection = enabled
        return view
    }
}

/**
 # ✂️ The short initializer

 Drops the three optional slots — title bar, empty-day view and grab handle —
 for callers that do not need them.

 What you give up:

 * **No title bar.** Draw your own above the view and page it with
   `EZCalendarAgendaPaging`.
 * **No grab handle.** The collapse is still fully driveable by scrolling the
   list, which is the primary gesture either way.
 * **Empty days render as a bare header.** The section still exists, so the
   two-way sync stays exact.
 */
extension EZCalendarAgendaView where TitleView == EmptyView, EmptyDayView == EmptyView, HandleView == EmptyView {

    public init(
        withCalendar calendar: Calendar,
        weekDayTitles: [String]? = nil,
        mode: Binding<EZCalendarAgendaMode>,
        selectedDate: Binding<Date>,
        calendarMonths: Binding<[CalendarMonth]>,
        events: [Event],
        eventDate: @escaping (Event) -> Date,
        @ViewBuilder weekdayItemViewContent: @escaping (String) -> WeekdayItemView,
        @ViewBuilder dayItemViewContent: @escaping (EZCalendarDayContext) -> DayItemView,
        @ViewBuilder listHeaderViewContent: @escaping (EZCalendarAgendaSection<Event>) -> ListHeaderView,
        @ViewBuilder eventItemViewContent: @escaping (Event) -> EventItemView
    ) {
        self.init(
            withCalendar: calendar,
            weekDayTitles: weekDayTitles,
            mode: mode,
            selectedDate: selectedDate,
            calendarMonths: calendarMonths,
            events: events,
            eventDate: eventDate,
            titleViewContent: { _ in EmptyView() },
            weekdayItemViewContent: weekdayItemViewContent,
            dayItemViewContent: dayItemViewContent,
            listHeaderViewContent: listHeaderViewContent,
            eventItemViewContent: eventItemViewContent,
            emptyDayViewContent: { _ in EmptyView() },
            handleViewContent: { EmptyView() }
        )
    }
}
