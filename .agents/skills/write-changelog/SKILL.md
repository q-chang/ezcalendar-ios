---
name: write-changelog
description: Draft or update EZCalendar release changelogs from the repository diff, preserving the project’s release-note format and separating library, Demo, documentation, and breaking changes.
---

# Write an EZCalendar changelog

Use this skill when preparing release notes or updating `CHANGELOG.md` for an
EZCalendar version.

## Canonical location and format

- Keep the release history in the repository root at `CHANGELOG.md`.
- Put the newest release below `Unreleased`, using `## EZCalendar X.Y.Z`.
- Use the sections `✨ Demo app`, `🐛 Fixes`, `📚 Documentation`, and
  `⚠️ Breaking changes` only when they contain relevant items.
- End a release with an `### Installation` Swift snippet using the exact plain
  semver tag and the repository URL.
- The git tag is authoritative; do not invent a source version constant.

## Workflow

1. Inspect the target version, merge base, commit range, and working tree.
2. Review the diff and classify only user-visible changes into library/API,
   Demo app, fixes, documentation, or breaking changes.
3. Verify claims against code. Do not call a release “no library changes” if
   `Sources/EZCalendar` changed. Treat a new public symbol as a library/API
   change even if behavior is backward compatible.
4. Preserve meaningful user-facing behavior and migration notes; omit internal
   implementation details and unrelated commits.
5. Update the matching release section in `CHANGELOG.md`. Keep `Unreleased`
   as a reusable template for the next version.
6. Check Markdown formatting and inspect the final diff. Do not tag or push
   unless the user explicitly asks and confirms the version.

## Version guidance

- Patch: fixes and documentation only.
- Minor: backward-compatible public API or feature additions.
- Major: removed/changed API or a raised platform floor.

When the version is not supplied, ask before writing a numbered release
heading; it changes the package installation guidance.
