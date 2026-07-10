# Website 3.2.1-alpha1

## Phase 1: page and navigation simplification

- Renamed the main `News` page to `Info` (`info.html`).
- Removed the central `Archive` entry from the main navigation.
- Added `LUR` to the main navigation.
- Added separate `News Archive` and `Commit Archive` pages.
- Added a `Documentation Archive` page and button beside `History`.
- Added the initial LUR page with the `Crater` entry.
- Added compatibility redirects:
  - `news.html` -> `info.html`
  - `archive.html` -> `info.html`
- Kept the existing archive data layout unchanged.

## Test notes

The build was regenerated locally with dynamic Moonbase/archive updates disabled, using the data and cache included in the archive.
