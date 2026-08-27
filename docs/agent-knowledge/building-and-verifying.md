# Building and verifying

**The month grid still ships no tests.** `Tests/EZCalendarTests/` covers
`EZCalendarAgendaView`'s logic (`swift test`), but nothing exercises
`EZCalendarItemViewModel`'s grid generation. For that there is no test
target in `Package.swift`. Everything below exists because of that.

## The one command that always applies

```bash
swift build
```

~7s cold. Builds the library for macOS in Swift 6 language mode. **Run it after
every source change.** A clean `swift build` is the floor for calling anything
done.

## Building for iOS / running the Demo

`swift build` only exercises the macOS slice. For an iOS build, or to see a change
on screen:

```bash
scripts/demo/run-demo.sh                    # newest available iPhone
scripts/demo/run-demo.sh -d "iPhone 17e"    # specific device
scripts/demo/run-demo.sh --build-only       # compile, no simulator
scripts/demo/run-demo.sh --console          # stream app stdout/stderr
scripts/demo/run-demo.sh --list             # available devices
scripts/demo/run-demo.sh --clean            # wipe derived data first
```

The script resolves a simulator dynamically (newest runtime, highest model), boots
it, builds, installs, and launches. Derived data goes to `.build/demo-dd`, covered
by the existing `/.build` gitignore rule. Device name can also come from
`$EZ_DEMO_DEVICE`.

> ⚠️ **This does not validate library changes.** The Demo links a sibling checkout
> — [landmine #1](landmines.md#1-the-demo-does-not-build-this-repos-sources). The
> script warns on every run.

Raw equivalent, if you need to vary something the script doesn't expose:

```bash
xcodebuild -workspace EZCalendar.xcworkspace -scheme Demo \
  -destination 'generic/platform=iOS Simulator' build
```

## Known-broken: the `EZCalendar` scheme

```bash
# BROKEN — do not use, and do not try to fix your way out of it
xcodebuild -scheme EZCalendar -destination 'generic/platform=iOS Simulator' build
```

Fails on a missing input file deleted in `9dfad87`. See
[landmine #2](landmines.md#2-ezcalendarxcodeproj-is-stale-and-does-not-build).

## Verifying date-math changes

Use the **`verify-calendar-grid`** skill. The short form:

`EZCalendarItemViewModel` is `internal`, so it cannot be exercised from an
external package. Copy the repo into a scratch directory, add a throwaway
`.testTarget`, and dump grids with `@testable import EZCalendar`.

```swift
import Testing
import Foundation
@testable import EZCalendar

func dumpGrid(_ label: String, _ month: Int, _ year: Int, _ cal: Calendar) {
    let vm = EZCalendarItemViewModel(
        calendarMonth: CalendarMonth(month: month, year: year),
        calendar: cal
    )
    print("=== \(label) \(month)/\(year) firstWeekday=\(cal.firstWeekday) rows=\(vm.calendarWeeks.count) ===")
    for week in vm.calendarWeeks {
        print(week.calendarDays.map { d in
            let n = d.date.map { cal.component(.day, from: $0) } ?? 0
            return d.isCurrentMonth ? String(format: "%4d", n) : String(format: "%3d*", n)
        }.joined())
    }
}
```

```bash
swift test --package-path "$SCRATCH/ezcopy" 2>&1 | sed -n '/=== /,$p'
```

**Capture the baseline before your change and diff after.** The skill carries a
recorded baseline for January and August 2026.

**Never commit a test target** into the user's repo unless they ask for one.

### Invariants worth asserting

- Every `CalendarWeek` has exactly **7** days.
- Row count is **5 or 6**, or 4 for a 28-day month starting on the first column.
- Leading padding runs contiguously up to the 1st; trailing padding from the last day.
- Padding cells are `isCurrentMonth == false`.

### Failures that are already there

If your dump shows these, it is the baseline, not your regression:
`firstWeekday` ignored, padding days never carrying events, and
`generateCalendarMonths(events:)` dropping its argument. See
[landmines.md](landmines.md).

## Verifying public API changes

A modifier being `public` is not proof a consumer can use the symbol. Compile
against the package as an external module:

```bash
mkdir -p apicheck/Sources/apicheck
cat > apicheck/Package.swift <<'EOF'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "apicheck",
    platforms: [.macOS(.v15)],
    products: [.library(name: "apicheck", targets: ["apicheck"])],
    dependencies: [.package(path: "/path/to/ezcalendar-ios")],
    targets: [.target(name: "apicheck",
        dependencies: [.product(name: "EZCalendar", package: "ezcalendar-ios")])]
)
EOF
# ...write Sources/apicheck/Check.swift, then:
swift build --package-path apicheck
```

This is how the table in [public-api.md](public-api.md) was produced, and how
every README example is checked. **Do this before documenting any API.**

## Checklist before reporting a change complete

1. `swift build` clean, no new warnings.
2. Date math touched → grid harness, diffed against baseline.
3. Public API touched → external-module compile check.
4. README examples touched → compile them, don't eyeball them.
5. Demo touched → `scripts/demo/run-demo.sh`.
