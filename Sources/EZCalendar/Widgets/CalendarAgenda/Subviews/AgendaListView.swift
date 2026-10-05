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
struct AgendaListView<Event: Identifiable, ListHeaderView: View, EventItemView: View, EmptyDayView: View, HandleView: View>: View where Event.ID: Sendable {

    @Binding var scrollRequest: AgendaScrollRequest?
    #if !os(iOS)
    @State private var scrollPosition: String?
    @State private var listOpacity = 1.0
    #endif

    let handleDragChanged: (Double) -> Void
    let handleDragEnded: (Double, Double) -> Void
    let sectionAppeared: (String) -> Void
    let scrollCommandReceived: (AgendaScrollRequest) -> Void
    let visibleSectionChanged: (String?) -> Void
    let listPositionSettled: () -> Void
    let listPositionFailed: () -> Void

    let sections: [EZCalendarAgendaSection<Event>]
    let contentRevision: Int
    let hasSelectableDateRange: Bool

    let listHeaderViewContent: (EZCalendarAgendaSection<Event>) -> ListHeaderView
    let eventItemViewContent: (Event) -> EventItemView
    let emptyDayViewContent: (Date) -> EmptyDayView
    let handleViewContent: () -> HandleView

    var body: some View {
        VStack(spacing: 0) {
            grabHandle
            list
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
                        handleDragChanged(value.translation.height)
                    }
                    .onEnded { value in
                        handleDragEnded(value.translation.height, value.velocity.height)
                    }
            )
    }

    private var list: some View {
        #if os(iOS)
        // `UITableView` supplies sticky section headers by default. Its bridge
        // verifies the rendered leading section after every programmatic jump
        // before acknowledging it — see `AgendaTableView` for why both
        // the SwiftUI-native `scrollPosition(id:anchor:)` implementation and
        // a `UICollectionView` bridge (two different, correctly-configured
        // sticky-header layouts) still weren't trustworthy. SwiftUI still
        // renders every pixel; this only owns identity, layout and
        // positioning.
        AgendaTableView(
            scrollRequest: $scrollRequest,
            sections: sections,
            sectionAppeared: sectionAppeared,
            scrollCommandReceived: scrollCommandReceived,
            visibleSectionChanged: visibleSectionChanged,
            listPositionSettled: listPositionSettled,
            listPositionFailed: listPositionFailed,
            contentRevision: contentRevision,
            hasSelectableDateRange: hasSelectableDateRange,
            listHeaderViewContent: listHeaderViewContent,
            eventItemViewContent: eventItemViewContent,
            emptyDayViewContent: emptyDayViewContent
        )
        #else
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            if section.isEmpty {
                                emptyDayViewContent(section.date)
                            } else {
                                ForEach(section.events) { event in
                                    eventItemViewContent(event)
                                }
                            }
                        } header: {
                            listHeaderViewContent(section)
                        }
                        // A section is one semantic day. Declaring it as a
                        // scroll target lets SwiftUI resolve distant lazy items
                        // from the layout, rather than a transient reader cache.
                        .id(section.id)
                        .onAppear {
                            sectionAppeared(section.id)
                        }
                    }

                    if !hasSelectableDateRange {
                        Color.clear.frame(height: geometry.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition, anchor: .top)
            .coordinateSpace(.named(AgendaCoordinateSpace.list))
            .scrollIndicators(.never)
            // Programmatic day changes are content replacements, never visible
            // scroll animations. Keep inherited calendar animations from
            // affecting the scroll container itself.
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            .opacity(listOpacity)
            .onChange(of: scrollPosition) { _, id in
                visibleSectionChanged(id)
            }
            .task(id: scrollRequest?.token) {
                guard let request = scrollRequest else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }

                scrollCommandReceived(request)

                // Hide the unavoidable lazy-layout relocation. The user sees a
                // stable list fade to its new top section, never rows moving
                // through the viewport.
                var immediate = Transaction()
                immediate.animation = nil
                immediate.disablesAnimations = true
                withTransaction(immediate) {
                    listOpacity = 0
                    scrollPosition = request.id
                }

                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }

                // Only now has the hidden scroll had a real layout pass to
                // land on. Reported positions before this point are the
                // lazy layout's own estimate settling, not a user scroll.
                listPositionSettled()

                withAnimation(.easeOut(duration: 0.16)) {
                    listOpacity = 1
                }

                if scrollRequest?.token == request.token {
                    scrollRequest = nil
                }
            }
        }
        #endif
    }
}
