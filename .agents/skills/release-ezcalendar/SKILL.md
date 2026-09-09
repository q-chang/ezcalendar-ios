---
name: release-ezcalendar
description: Cut a new EZCalendar version. Use when asked to release, tag, bump the version, or publish an update for SwiftPM consumers.
---

# Releasing EZCalendar

EZCalendar is distributed **only** through Swift Package Manager over git. There is
no `podspec`, no version constant in source, and no changelog file. **The git tag
is the version.** Nothing else needs bumping.

## Existing tags

```
1.3.1   2026-02-10
1.3.0   2025-12-19
```

Plain semver, no `v` prefix. Match that format exactly — SwiftPM resolves
`from: "1.3.1"` against these, and an inconsistent prefix breaks resolution for
existing consumers.

## Procedure

1. Confirm the working tree is clean and `main` is up to date.
2. `swift build` must succeed (see the `build-ezcalendar` skill).
3. If date logic changed, run the `verify-calendar-grid` harness and compare against its baseline.
4. Update `README.md` if the public API or its known limitations changed.
5. Pick the version:
   - **patch** — bug fix, docs, no API change
   - **minor** — new public API, backward compatible
   - **major** — removed or changed existing public API, or a raised platform floor
6. Tag and push:

```bash
git tag 1.3.2
git push origin 1.3.2
```

## Ask first

Tagging and pushing are outward-facing and effectively irreversible for anyone
who has already resolved the version. **Confirm the version number with the user
before pushing the tag**, and never push a tag as a side effect of another task.

## Watch out

- **Raising a platform floor is a major bump.** `Package.swift` currently declares `.iOS(.v17)` / `.macOS(.v15)`.
- **Making an internal member public is a minor bump, not a patch.** Several types in this package are `public` with internal members (see AGENTS.md) — widening any of them is new API.
- **The sibling `EZCalendar-Swift` repo is separate.** It has its own remote and its own tags. Releasing here does not release that one, and vice versa. (The Demo no longer links it.)
