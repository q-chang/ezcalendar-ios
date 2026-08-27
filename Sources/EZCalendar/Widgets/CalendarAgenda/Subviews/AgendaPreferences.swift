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

/// How far the list has scrolled past its top: positive into content, negative
/// while rubber-banding above the first section.
struct AgendaListOffsetKey: PreferenceKey {
    static var defaultValue: Double { 0 }

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = nextValue()
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

    /// Reports how far the list content has travelled past the top of its
    /// scroll view. The content's own top edge is the only probe needed:
    /// negated, its `minY` *is* the scroll offset.
    func measureListOffset() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AgendaListOffsetKey.self,
                    value: -proxy.frame(in: .named(AgendaCoordinateSpace.list)).minY
                )
            }
        )
    }
}
