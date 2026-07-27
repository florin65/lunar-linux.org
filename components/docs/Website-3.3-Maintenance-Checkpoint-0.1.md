# Website 3.3 Maintenance Checkpoint 0.1

**Version:** 0.1
**Date:** 2026-07-27
**Project:** Lunar Linux Website 3.3
**Phase:** Post-componentization maintenance
**Status:** Proposed acceptance checkpoint

## 1. Purpose

This checkpoint records the maintenance and documentation work completed after Componentization Phase 2.

Its purpose is to establish the verified Website 3.3 baseline, distinguish resolved maintenance findings from active external conditions, and define the next responsible development posture.

This checkpoint does not open a new feature phase.

## 2. Starting condition

Componentization Phase 2 ended with three accepted standalone presentation components:

```text
components/archive-links.sh
components/news-journal.sh
components/commit-journal.sh
```

The phase also established a healthy stopping point:

```text
prepared data
→ deterministic component renderer
→ HTML fragment
```

No additional standalone component was justified by the remaining implementation.

The next work therefore shifted from extraction to repository maintenance, architecture alignment and validation of the accepted Website 3.3 state.

## 3. Maintenance results

### 3.1 Repository hygiene

Three stale tracked artifacts were removed:

```text
cache/.page-list.NKZ9ci
docs/new.zip
docs/news/2026-06-19-website-2-8-released.html
```

The findings represented:

- a local temporary page-list file;
- an obsolete generated archive;
- a stale public news page no longer represented by the current source set.

The cleanup confirmed that generated public output must remain aligned with current authoritative sources and manifests.

### 3.2 Architecture documentation

`docs/Website-Architecture.md` was aligned with Website 3.3.

The document now records:

- Website 3.3 as the current project baseline;
- `components/` as an explicit architectural area;
- semantic page rendering and prepared-fragment rendering as separate responsibilities;
- the accepted standalone component layer;
- direct component testing;
- incremental build-state maintenance;
- the evidence-driven stopping rule for future component extraction.

### 3.3 Component documentation

The component documentation was promoted from draft status and aligned with the implemented state.

Accepted documents now include:

```text
components/docs/Action-Links-Contract-0.1.md
components/docs/News-Journal-Contract-0.1.md
components/docs/News-Journal-Inventory-0.1.md
components/docs/Commit-Journal-Contract-0.1.md
components/docs/Commit-Journal-Inventory-0.1.md
components/docs/Website-Component-Inventory-0.1.md
components/docs/Component-Specification-0.1.md
components/docs/Componentization-Phase-2-Consolidation-Checkpoint-0.1.md
```

Two remaining operationally stale statements were corrected:

- the component specification now refers to Website 3.3;
- the News Journal boundary is recorded as accepted and implemented rather than merely candidate.

Historical candidate language in inventory sections was preserved where it records the actual state of earlier analysis.

### 3.4 General project documentation

`README.md` and `MARKDOWN.md` were aligned with the real Website 3.3 implementation.

The update removed obsolete descriptions of:

- Website 2.5 as the current version;
- generated output under `public/`;
- the current generator as only a Bash prototype;
- a speculative future Nim generator;
- an outdated component roadmap.

The documents now describe:

- generated public output under `docs/`;
- the active component layer;
- deterministic incremental builds;
- archive recovery and strict modes;
- current build and maintenance commands;
- evidence-driven future development.

## 4. Validation evidence

The accepted maintenance state is supported by the following evidence:

```text
Git working tree clean after each accepted commit
git diff --check clean
News Journal direct tests passed
Commit Journal direct tests passed
full Website build completed
44 pages unchanged when no relevant source changed
0 failed pages
stale generated artifacts removed
architecture and component documents aligned with Website 3.3
general project documents aligned with Website 3.3
```

The final observed build report recorded:

```text
Status: completed with warnings
Pages generated: 0
Pages unchanged: 44
Pages failed: 0
```

This is valid evidence of deterministic incremental behavior: no page was rebuilt when no relevant source or dependency changed.

## 5. External TLS condition

The Lunar public hosts currently present expired TLS certificates, including the daily ISO source used by the Website generator.

The Website 3.3 build handles the daily ISO endpoint through a narrowly scoped temporary exception:

```text
strict verified fetch first
→ verified fetch fails because the certificate is expired
→ optional insecure retry only for the declared ISO URL
→ explicit warning recorded in the build report
```

The current warning is therefore expected:

```text
daily ISO metadata refreshed through the temporary insecure TLS exception
```

This exception is not a general relaxation of TLS validation.

It must be removed when the external certificate is renewed and strict verification succeeds again.

## 6. Concurrent Moonbase update observation

One build temporarily failed with:

```text
unexpected branch for other: unknown
```

The failure occurred while the local Moonbase `other` repository was being updated from GitHub.

The branch state was transient. A later build completed successfully after the update finished.

Decision:

- no Website code change is required;
- the strict branch check remains valid;
- the event is preserved as operational evidence that builds should not run concurrently with Moonbase repository updates.

## 7. Current accepted baseline

Website 3.3 now has the following accepted characteristics:

```text
static and inspectable shell-based generator
Markdown and simple metadata as authoritative content inputs
Git as project source of truth
GitHub Pages output under docs/
deterministic incremental page rebuilding
persistent signatures and build state
tolerant archive recovery with optional strict validation
controlled stale-output cleanup
explicit administrative build reports
semantic renderer ownership
small tested presentation components
accepted architecture and component documentation
aligned general project documentation
```

The repository has reached a coherent maintenance baseline.

## 8. Boundaries preserved

The maintenance work preserved the following architectural boundaries:

- source acquisition remains outside presentation components;
- policy, sorting and archive recovery remain producer responsibilities;
- semantic Markdown interpretation remains in `tools/render-page.sh`;
- prepared repeated records may be rendered by standalone components;
- generated public HTML is not the preferred editing surface when an authoritative source exists;
- external TLS exceptions remain narrow, visible and temporary;
- transient environmental failures are not converted automatically into architectural changes.

## 9. Lessons recorded

The maintenance phase produced several reusable lessons:

1. A successful output comparison is not evidence when the producer command failed before replacing its output.
2. Documentation alignment is part of accepting an implementation phase, not optional cleanup.
3. Historical analysis language should remain preserved when later sections clearly record the accepted outcome.
4. Generated public output requires periodic stale-file inspection even when normal manifests are correct.
5. Strict environmental checks may reveal valid transient states during concurrent repository updates.
6. A temporary security exception must remain endpoint-specific, explicit and removable.
7. A healthy stopping point is a positive engineering result; further abstraction requires new evidence.

## 10. Development posture

Website 3.3 is now in active maintenance and evidence-driven evolution.

No new componentization phase or broad generator rewrite is justified at this checkpoint.

The next change should arise from one of the following:

```text
a reproducible maintenance problem
new repeated implementation
a stable feature boundary
verified project or community need
removal of the temporary TLS exception after certificate renewal
```

Routine dynamic-data refreshes and content updates may continue without reopening the architecture.

## 11. Acceptance statement

Website 3.3 post-componentization maintenance is accepted as complete when this checkpoint is reviewed and committed.

The accepted result is:

```text
Componentization Phase 2 closed
repository hygiene restored
architecture documentation aligned
component documentation accepted and aligned
general project documentation aligned
incremental build verified
known TLS warning controlled
transient Moonbase update failure understood
no further abstraction currently justified
```

This checkpoint establishes the current Website 3.3 operational and architectural baseline.
