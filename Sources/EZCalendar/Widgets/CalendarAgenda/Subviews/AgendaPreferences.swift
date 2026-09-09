//
//  AgendaPreferences.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import SwiftUI

/// Coordinate space names the agenda measures against.
enum AgendaCoordinateSpace {
    /// The agenda list's scroll view. Section headers and the content's top edge
    /// are measured in here, so `minY` means "distance below the list's top".
    static let list = "ez.agenda.list"
}

/// Natural, unclipped height of each month page's grid, keyed by page id.
///
/// Merged rather than overwritten, because several pages are on screen at once
/// mid-swipe and each reports its own height.
struct AgendaGridHeightKey: PreferenceKey {
    static var defaultValue: [String: Double] { [:] }

    static func reduce(value: inout [String: Double], nextValue: () -> [String: Double]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Where every visible section header sits in the list's coordinate space.
struct AgendaHeaderOffsetKey: PreferenceKey {
    static var defaultValue: [AgendaHeaderOffset] { [] }

    static func reduce(value: inout [AgendaHeaderOffset], nextValue: () -> [AgendaHeaderOffset]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {

    /// Reports this view's natural height under `id`.
    ///
    /// Attached as a `background`, so measuring never influences the layout it
    /// is measuring — the geometry reader inherits the size rather than
    /// proposing one.
    func measureGridHeight(id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AgendaGridHeightKey.self,
                    value: [id: proxy.size.height]
                )
            }
        )
    }

    /// Reports this header's vertical position within the agenda list.
    func measureHeaderOffset(id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AgendaHeaderOffsetKey.self,
                    value: [
                        AgendaHeaderOffset(
                            id: id,
                            minY: proxy.frame(in: .named(AgendaCoordinateSpace.list)).minY
                        )
                    ]
                )
            }
        )
    }

    // NOTE: there is deliberately no whole-content scroll-offset probe here, and
    // adding one back will not work.
    //
    // Two obvious probes were tried and both fail the same way: a
    // `GeometryReader` in the `background` of the `LazyVStack`, and a 1pt
    // sentinel above it. Each reports exactly once, on first layout, and then
    // goes permanently silent — SwiftUI stops resolving geometry for views far
    // outside the viewport, and this list opens scrolled thousands of points
    // down onto the selected day. A silent probe is worse than none: it disables
    // whatever is built on it without failing.
    //
    // The section headers above are the one measurement that stays live, because
    // they only exist while they are near the viewport. If you ever need a scroll
    // measurement here, derive it from those — and verify it fires more than once
    // before building anything on it.
}
