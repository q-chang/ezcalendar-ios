//
//  AgendaListView.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI

/// The bottom half of the agenda: a continuous, date-grouped list with sticky
/// headers, which doubles as the collapse gesture's driver.
///
/// ## Why the list can collapse the calendar without fighting itself
///
/// A `DragGesture` laid over a `ScrollView` competes with it: one of the two
/// wins each frame and the result feels broken. This view never adds that
/// gesture. It reads the list's **own scroll offset** and lets
/// `EZCalendarAgendaLogic.progress(forListOffset:mode:threshold:)` decide how
/// much of that movement the collapse consumes:
///
/// ```
/// .monthly, list at top     scroll up  →  offset 0 → 100  →  calendar collapses
/// .weekly,  list mid-content scroll     →  offset changes  →  calendar unaffected
/// .weekly,  list at top     over-scroll →  offset 0 → -100 →  calendar expands
/// ```
///
/// The collapse therefore only ever consumes movement the list itself has no use
/// for, which is exactly the rule that makes the interaction feel native.
///
/// The grab handle above the list adds an explicit `DragGesture` for users who
/// reach for it, and it outranks the scroll driver while the finger is down.
///
/// ## The sticky header is the sync signal
///
/// Every header reports its position through `AgendaHeaderOffsetKey`. Whichever
/// one is pinned at the top is, by definition, the day the user is looking at —
/// so that is the day the calendar selects. See
/// `EZCalendarAgendaLogic.topMostSectionID(headerOffsets:topInset:)`.
struct AgendaListView<Event: Identifiable, ListHeaderView: View, EventItemView: View, EmptyDayView: View, HandleView: View>: View {

    @ObservedObject var viewModel: EZCalendarAgendaViewModel

    let sections: [EZCalendarAgendaSection<Event>]

    let listHeaderViewContent: (EZCalendarAgendaSection<Event>) -> ListHeaderView
    let eventItemViewContent: (Event) -> EventItemView
    let emptyDayViewContent: (Date) -> EmptyDayView
    let handleViewContent: () -> HandleView

    var body: some View {
        VStack(spacing: 0) {
            grabHandle
            list
        }
        .onPreferenceChange(AgendaHeaderOffsetKey.self) { offsets in
            viewModel.headerOffsetsChanged(offsets)
        }
    }

    /// The caller's grab pill, with the one explicit collapse gesture in the
    /// component. `minimumDistance: 1` keeps a tap on the handle from being read
    /// as a zero-length drag.
    private var grabHandle: some View {
        handleViewContent()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        viewModel.handleDragChanged(translation: value.translation.height)
                    }
                    .onEnded { value in
                        viewModel.handleDragEnded(translation: value.translation.height)
                    }
            )
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            // Every day in range has a section, so a day with
                            // nothing scheduled still has something to scroll to.
                            if section.isEmpty {
                                emptyDayViewContent(section.date)
                            } else {
                                ForEach(section.events) { event in
                                    eventItemViewContent(event)
                                }
                            }
                        } header: {
                            listHeaderViewContent(section)
                                .id(section.id)
                                .measureHeaderOffset(id: section.id)
                        }
                    }
                }
            }
            .coordinateSpace(.named(AgendaCoordinateSpace.list))
            .scrollIndicators(.never)
            .onChange(of: viewModel.scrollRequest) { _, request in
                guard let request else { return }

                // Deliberately *not* `collapseAnimation`: that one is the
                // caller's, and a slow value there would leave the list still
                // travelling long after any sync latch could reasonably wait.
                if request.animated {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(request.id, anchor: .top)
                    }
                } else {
                    proxy.scrollTo(request.id, anchor: .top)
                }

                // Clear the request so selecting the same day twice scrolls
                // twice — `onChange` only fires on a *changed* value.
                viewModel.scrollRequest = nil
            }
        }
    }
}
