//
//  AgendaListView.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI

/// The bottom half of the agenda: a continuous, date-grouped list with sticky
/// headers.
///
/// ## The list never changes the mode
///
/// Scrolling here scrolls here, and nothing else. The calendar switches between
/// `.monthly` and `.weekly` only through the grab handle above the list (or the
/// caller's `mode` binding, or a day tap).
///
/// The handle's drag tracks the finger and commits on release; because it is a
/// gesture on its own view rather than one layered over this `ScrollView`, the
/// two never compete.
///
/// An earlier version drove the collapse from this list's scroll offset, on the
/// theory that it would feel native. It did not: reading down through a busy
/// day's events collapsed the calendar out from under you, and an over-scroll at
/// the top expanded it again — both without being asked. The gesture is worth
/// having only where it is unambiguous, which is the handle.
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

    /// The caller's grab pill — the only surface in the component that switches
    /// modes by gesture.
    ///
    /// `contentShape` makes the caller's whole handle frame draggable rather than
    /// just the pixels they drew, so a thin pill is still a usable target. How
    /// tall that frame is remains the caller's call; the library does not pad it.
    ///
    /// `minimumDistance: 1` keeps a tap on the handle from registering as a
    /// zero-length drag.
    ///
    /// ⚠️ **`coordinateSpace: .global` is load-bearing.** The handle sits at the
    /// bottom edge of the calendar, so collapsing the calendar moves the handle
    /// up — under the finger that is doing the collapsing. A `DragGesture`
    /// reports translation in the coordinate space of the view it is attached to,
    /// so in the default (local) space the handle's own movement is subtracted
    /// from the drag: the gesture damps itself, roughly halving. Measured that
    /// way a 150pt drag reports about 75pt, and the commit threshold silently
    /// needs twice the distance the caller asked for. `.global` does not move
    /// with the calendar, so a point of finger travel is a point of translation.
    private var grabHandle: some View {
        handleViewContent()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        viewModel.handleDragChanged(translation: value.translation.height)
                    }
                    .onEnded { value in
                        viewModel.handleDragEnded(
                            translation: value.translation.height,
                            velocity: value.velocity.height
                        )
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
