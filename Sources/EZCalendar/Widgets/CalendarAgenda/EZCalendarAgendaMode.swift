//
//  EZCalendarAgendaMode.swift
//  EZCalendar
//
//  Created by wisanu on 27/8/2569 BE.
//

import Foundation

/**
 # 🗓️ Display mode for `EZCalendarAgendaView`

 The agenda view shows the same calendar in one of two heights. The mode is a
 `@Binding`, so it can be driven three ways at once and they all stay in sync:

 | Driver | What happens |
 | --- | --- |
 | The user drags the grab handle | The mode flips once the drag passes the snap threshold. |
 | The user taps a day while `.monthly` | The mode auto-snaps to `.weekly`. |
 | The caller assigns the binding | The calendar animates to the new mode. |

 ## Cases

 * **`.monthly`** — the full month grid, 4–6 week rows. The default.
 * **`.weekly`** — a single week row: the one containing `selectedDate`.

 Horizontal paging follows the mode: `.monthly` pages by month, `.weekly` pages
 by week. See `EZCalendarAgendaPaging` for the selection rules that apply when a
 page changes.
 */
public enum EZCalendarAgendaMode: String, Hashable, Sendable, CaseIterable {

    /// The full month grid — 4, 5 or 6 week rows depending on the month.
    case monthly

    /// A single week row: the week containing the selected date.
    case weekly

    /// `0` for `.monthly`, `1` for `.weekly` — the resting value of the
    /// collapse progress that drives every interactive animation in the view.
    var progress: Double {
        switch self {
        case .monthly: return 0
        case .weekly: return 1
        }
    }
}
