# Website 3.3 Architecture Refinement Checkpoint 0.1

**Version:** 0.1
**Date:** 2026-08-03
**Project:** Lunar Linux Website 3.3
**Phase:** Architecture audit and controlled refinement
**Status:** Accepted architecture checkpoint
**Accepted code baseline:** `6731de487c96691f7413f0bcc142b0881b6cfe04` — `Refine page signature dependencies`

## 1. Purpose

This checkpoint records the formal completion of the Website 3.3 architecture audit and the four small refinements accepted from it.

The work began as a read-only investigation of code responsibility, runtime dependencies, coupling and shared state. It did not assume that a refactor was required. Each change was accepted only after a concrete defect or imprecise boundary was demonstrated and a smaller correction was available.

This checkpoint:

- preserves the audit documents as historical Evidence;
- records the implemented decisions separately from the earlier candidate state;
- establishes the current code baseline;
- updates the architecture description;
- defines an explicit stopping point.

It does not open a new componentization phase or authorize a broad generator rewrite.

## 2. Starting condition

The audit began from commit:

```text
4662e7ac4a06df7881aa71b2b5f2977baa8abcec
Add Website 3.2 release news
```

The observed architecture already had useful boundaries:

```text
core build lifecycle
→ domain data producers
→ prepared semantic records
→ deterministic presentation components
→ page composition and publication
```

The audit also found four focused candidates:

```text
1. Editorial News Lifecycle Boundary
2. Editorial Warning and Report Contract
3. Moonbase Page-Data Preparation Boundary
4. Signature Precision Boundary
```

The candidates were evaluated in order of correctness and operational value rather than by code size.

## 3. Audit method

The work followed this sequence:

```text
Phase A — Observe
  A1 Code Responsibility Inventory
  A2 Runtime and Build Dependency Map
  A3 Coupling and State Inventory

Phase B — Interpret
  define the hard core
  review extension boundaries
  evaluate one candidate at a time

Phase C — Decide
  accept only narrow, reversible changes

Phase D — Implement
  change one boundary at a time

Phase E — Validate
  direct tests
  deterministic builds
  output comparison
  warning and status checks
  incremental behavior

Phase F — Accept
  checkpoint
  architecture alignment
  explicit stopping point
```

The A1, A2 and A3 documents remain records of what was observed at their original baseline. Statements that were true before implementation are not rewritten retroactively.

## 4. Accepted refinement 1 — Editorial News Lifecycle Boundary

**Commit:**

```text
8f24a74 Decouple editorial news from dynamic data refresh
```

### 4.1 Finding

Editorial news under `src/news/` is authoritative local content, but its current-page and journal generation was scheduled inside the remote dynamic-data refresh phase.

Therefore:

```sh
UPDATE_DYNAMIC_DATA=no UPDATE_ARCHIVE=no ./build-site.sh
```

could regenerate `docs/data/news.json` while leaving current news pages or `cache/community-news.html` stale.

### 4.2 Accepted boundary

Editorial news generation now has its own lifecycle:

```text
src/news/*.md
→ build_editorial_news()
  ├── tools/build-community-news.sh
  └── build_news_json() when GENERATE_NEWS_JSON=yes
→ current news pages, journal and JSON remain consistent
```

It runs independently of Moonbase repository refresh and daily ISO retrieval.

### 4.3 Preserved policy

The change preserved:

- `UPDATE_DYNAMIC_DATA` as control for remote/repository-derived data;
- `UPDATE_ARCHIVE` as control for archive processing;
- `GENERATE_NEWS_JSON` as the explicit JSON-generation switch;
- current news source validation and tolerant rejection behavior;
- archive processing as a separate last phase.

## 5. Accepted refinement 2 — Editorial Warning and Report Contract

**Commit:**

```text
c4db703 Record editorial warnings and propagate strict build failures
```

### 5.1 Finding

Current editorial-news validation warnings could be visible on stderr but absent from the persistent build report.

That permitted an inconsistent administrative result:

```text
warning visible during execution
+ Editorial or Dynamic Data warnings reported as 0
+ STRICT_BUILD unable to act on the warning
```

### 5.2 Accepted contract

Editorial generation now uses a controlled warning path:

```text
producer stderr
→ editorial news log
→ unique accepted warning messages
→ Problems section in build report
→ Editorial News warning count
→ completed with warnings status
→ STRICT_BUILD authority
```

Fatal producer errors remain fatal. Tolerated invalid-source warnings remain warnings, but they are now persistent Evidence rather than transient terminal output only.

### 5.3 Authority result

The build report is again the authoritative administrative Artifact for strict validation.

```text
accepted warning exists
→ report records it
→ status reflects it
→ STRICT_BUILD can fail intentionally
```

## 6. Accepted refinement 3 — Moonbase Page-Data Preparation Boundary

**Commit:**

```text
8ffdba6 Separate Moonbase page-data preparation
```

### 6.1 Finding

`prepare_moonbase_values()` combined two passes over the same generated Moonbase JSON with fallback, component invocation and publication of page values.

The duplicated parsers increased maintenance risk, while the actual domain boundary was already clear:

```text
Moonbase JSON
→ page statistics + prepared Commit Journal TSV
```

### 6.2 Accepted boundary

The current implementation separates:

```text
prepare_moonbase_page_data()
→ parse Moonbase JSON once
→ calculate four direct statistics
→ prepare five-field Commit Journal TSV

prepare_moonbase_values()
→ own fallback behavior
→ validate returned statistics
→ derive other-commit count
→ invoke Commit Journal
→ publish values and fragment paths to page composition
```

The new function remains internal to `tools/build-site.sh`. It is domain preparation, not a presentation component and not a generic plugin.

### 6.3 Preserved semantics

The implementation preserves:

- Moonbase-only category filtering;
- input order for journal records;
- repository counting;
- original non-empty module counting for statistics;
- journal module fallback derived from title when required;
- version-bump classification;
- five scalar page values;
- empty-input fallback HTML;
- Commit Journal input contract;
- temporary-file cleanup and failure behavior.

### 6.4 Validation

Validation established:

```text
shell syntax valid
git diff --check clean
Commit Journal tests passed
News Journal tests passed
full Website build passed
STRICT_BUILD validation passed
44 generated pages remained byte-for-byte identical
```

## 7. Accepted refinement 4 — Signature Precision Boundary

**Commit:**

```text
6731de4 Refine page signature dependencies
```

### 7.1 Finding

Every ordinary page signature included the source bytes of:

```text
components/archive-links.sh
```

This caused all ordinary pages to rebuild after any component-source change, including comments or internal refactoring that did not change rendered HTML.

### 7.2 Accepted boundary

The direct component-source input was removed from `page_build_signature()`.

The authoritative dependency remains the fully expanded rendered body:

```text
Archive Links source or prepared records
→ Archive Links HTML fragment
→ template expansion
→ final rendered body
→ page signature
```

If component behavior changes public HTML, the affected page body changes and its signature changes. If implementation text changes without changing output, no page rebuild is required.

### 7.3 Rejected alternatives

The correction deliberately did not introduce:

- per-page component registries;
- placeholder dependency discovery;
- conditional source hashing;
- a plugin framework;
- a new incremental engine.

The existing rendered-output dependency was already sufficient.

### 7.4 Validation

The accepted result was:

```text
first build after formula change:
  generated: 44
  unchanged: 0
  failed: 0

stable second build:
  generated: 0
  unchanged: 44
  failed: 0

public docs/ output:
  byte-for-byte identical

warnings: 0
stale outputs removed: 0
stale signatures removed: 0
```

The 44 committed signature updates establish the new incremental baseline.

## 8. Resulting architecture

The accepted Website 3.3 execution shape is now:

```text
initialize build and report
→ refresh remote/repository dynamic data when enabled
→ regenerate authoritative local editorial news
→ record Dynamic Data and Editorial News results separately
→ load scalar dynamic values
→ prepare Moonbase page data through one internal pass
→ prepare presentation fragments
→ render and sign ordinary pages from final rendered content
→ process archive last
→ render archive pages
→ finalize report and owned build state
```

The refinements improve boundaries without changing the fundamental architecture.

## 9. Validation evidence for the complete phase

The accepted code baseline is supported by:

```text
Git branch main
HEAD and origin/main aligned
working tree clean
shell syntax checks passed
git diff --check passed
Commit Journal component tests passed
News Journal component tests passed
editorial news local lifecycle verified
editorial warnings recorded in the build report
STRICT_BUILD warning authority verified
Moonbase output byte-for-byte identical after extraction
Signature Precision output byte-for-byte identical
stable incremental build: 0 generated, 44 unchanged, 0 failed
0 Dynamic Data warnings in final baseline verification
0 Editorial News warnings in final baseline verification
0 maintenance warnings
0 stale outputs removed
0 stale signatures removed
```

## 10. Boundaries preserved

The phase preserved the following decisions:

- Git and authoritative source files remain the source of truth;
- editorial Markdown remains local authoritative content;
- remote dynamic refresh remains optional;
- archive processing remains last and separately controlled;
- raw archive preservation remains strict;
- public archive regeneration remains tolerant where preservation requires it;
- semantic Markdown interpretation remains in `tools/render-page.sh`;
- prepared repeated records remain the input to standalone presentation components;
- `tools/build-site.sh` remains the explicit shell orchestrator;
- independently runnable domain scripts retain their autonomy;
- generated HTML is not manually edited when a source exists;
- no generic plugin, registry or broad shared-library layer is introduced.

## 11. Findings intentionally postponed

The audit recorded additional observations that do not justify changes at this checkpoint:

```text
hard-coded domain placeholder wiring
possible redundant early archive-fragment preparation
probable legacy news-signature directory hooks
probable unused archive_write_atomic() helper
small main-shell transient-variable leakage
incomplete signal cleanup for a few orchestration temporaries
repeated restricted JSON mechanics with different semantic contracts
repeated news validation with intentionally different continuation policies
page and signature publication as separate recoverable operations
```

These observations remain candidates for future evidence-based maintenance. They are not defects accepted for immediate correction, and they must not be removed or consolidated without fresh verification.

## 12. Lessons recorded

1. Candidate order must follow correctness and operational value, not the size of the proposed extraction.
2. Local authoritative content must not be controlled by unrelated remote-refresh policy.
3. A tolerated warning must reach the persistent administrative Artifact when strict policy depends on that Artifact.
4. Domain preparation may deserve an internal boundary without becoming a standalone component.
5. Fully rendered content is the correct signature authority when component output is already embedded in that content.
6. Over-inclusion in a signature is safe but can still be corrected when redundancy is proven.
7. Historical audit documents should preserve their original observations; later checkpoints record supersession.
8. A small shell architecture can gain precision without adopting a framework.
9. Byte-identical public output is necessary evidence for behavior-preserving internal refinements.
10. A healthy stopping point is part of architecture, not an absence of ambition.

## 13. Current accepted baseline

The code baseline established by this phase is:

```text
6731de487c96691f7413f0bcc142b0881b6cfe04
Refine page signature dependencies
```

Its accepted refinement chain is:

```text
8f24a74 Decouple editorial news from dynamic data refresh
c4db703 Record editorial warnings and propagate strict build failures
8ffdba6 Separate Moonbase page-data preparation
6731de4 Refine page signature dependencies
```

At this baseline:

```text
Editorial News Lifecycle Boundary — accepted and closed
Editorial Warning and Report Contract — accepted and closed
Moonbase Page-Data Preparation Boundary — accepted and closed
Signature Precision Boundary — accepted and closed
```

## 14. Development posture and stopping point

The architecture audit and controlled-refinement phase has reached its stopping point.

No further change from the audit backlog is automatically authorized.

Website 3.3 returns to:

```text
content work
feature work based on demonstrated need
routine data refresh
maintenance based on reproducible evidence
removal of temporary external exceptions when their conditions disappear
```

A new architecture intervention requires new Evidence such as:

```text
a reproducible correctness problem
a repeated maintenance failure
stable new duplication
a clear ownership conflict
a measurable incremental-build defect
a verified project or community requirement
```

## 15. Acceptance statement

The Website 3.3 architecture audit and controlled-refinement phase is accepted as complete when this checkpoint and the aligned architecture document are reviewed and committed.

The accepted result is:

```text
Phase A observation complete
Phase B boundary interpretation complete
four focused candidates accepted
four focused implementations validated
public output preserved
incremental precision improved
warning authority restored
architecture documentation aligned
remaining findings explicitly postponed
new Website 3.3 code baseline established
```

This checkpoint closes the audit-derived refactoring phase without opening a new abstraction program.
