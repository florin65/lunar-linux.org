# Website 3.3 Architecture Refinement — Closure Checkpoint 0.1

**Version:** 0.1  
**Date:** 2026-08-03  
**Project:** Lunar Linux Website  
**Release line:** Website 3.3  
**Status:** Accepted and complete  
**Authority:** Florin  
**Collaborating AI actor:** Nim  
**Repository:** `florin65/lunar-linux.org`  
**Branch:** `main`

## 1. Checkpoint purpose

This checkpoint formally closes the Website 3.3 architecture-refinement cycle.

The cycle began as a read-only investigation of code responsibilities, runtime dependencies, shared state, coupling, generated-output ownership and failure semantics. It continued only where observed Evidence justified a small and reversible correction.

No generic plugin framework, shared shell framework or broad rewrite was introduced.

## 2. Accepted refinement boundaries

### 2.1 Editorial News Lifecycle Boundary

Authoritative local editorial news was separated from remote dynamic-data refresh policy.

Current editorial content can now be regenerated consistently even when Moonbase and daily ISO refreshes are disabled.

The following outputs belong to one coherent local editorial lifecycle:

```text
src/news/*.md
→ current news pages
→ current News Journal fragment
→ public news JSON
```

### 2.2 Editorial Warning and Report Contract

Accepted editorial-news warnings now reach the persistent build report.

The report reflects rejected editorial sources rather than leaving relevant Evidence only on transient stderr output.

`STRICT_BUILD=yes` can therefore exercise authority over the documented warning state.

### 2.3 Moonbase Page-Data Preparation Boundary

Moonbase page-data interpretation was separated from orchestration.

```text
prepare_moonbase_page_data()
→ parse Moonbase records once
→ calculate page statistics
→ produce prepared Commit Journal TSV

prepare_moonbase_values()
→ manage fallback behavior
→ invoke the presentation component
→ publish prepared values to page composition
```

The duplicate parsing passes were consolidated without changing generated Website output.

### 2.4 Signature Precision Boundary

The page-signature formula no longer hashes the source bytes of `components/archive-links.sh` unconditionally.

The effective rendered output remains part of every page signature and therefore remains the authoritative content dependency.

Consequences:

```text
component implementation changes without HTML changes
→ no unnecessary full-site rebuild

component output changes
→ affected final_rendered content changes
→ affected pages are regenerated
```

## 3. Validation evidence

The accepted baseline passed:

```text
shell syntax checks
git diff --check
Commit Journal component tests
News Journal component tests
deterministic local builds
strict-build validation
incremental two-pass validation
generated Website comparison
temporary and stale-state checks
```

Final incremental result:

```text
generated: 0
unchanged: 44
failed: 0
warnings: 0
stale outputs removed: 0
stale signatures removed: 0
```

The public `docs/` tree remained byte-for-byte identical across the behavior-preserving refinements.

## 4. Architectural result

Website 3.3 now demonstrates the following stable structure:

```text
authoritative content and data
→ domain-owned preparation
→ prepared semantic records or fragments
→ deterministic presentation components
→ page composition
→ effective-output signatures
→ atomic publication
→ persistent build report and maintenance
```

The core orchestrator remains explicit and inspectable.

Domain responsibilities are separated only where a proven boundary improves correctness, testability or ownership.

## 5. Preserved design decisions

The refinement cycle confirms the following decisions:

- no generic plugin system;
- no component registry;
- no broad shared shell library;
- no generic table abstraction;
- no renderer rewrite;
- no incremental-engine rewrite;
- archive processing remains last;
- strict archive preservation remains distinct from tolerant public regeneration;
- standalone domain scripts retain operational independence;
- generated output remains derived state, not authoritative source.

## 6. Deferred observations

The following findings remain available for future Evidence-driven review but do not constitute an active refactoring program:

- hard-coded domain placeholder wiring;
- probable redundant initial archive-fragment preparation;
- dormant news-signature ownership hooks;
- possibly unused archive support helpers;
- small orchestration temporary-file cleanup gaps;
- duplicated restricted parsing with different semantic contracts;
- page and signature publication as separate recoverable operations.

No change is authorized solely because an item appears in this list.

## 7. Operating posture after checkpoint

Website 3.3 enters:

```text
maintenance
+ real-world observation
+ content development
+ evidence-driven correction
```

Future architectural changes require:

1. an observed problem or repeated need;
2. a defined ownership boundary;
3. a smaller and clearer contract;
4. an explicit validation method;
5. no unrelated behavioral change.

## 8. Formal declaration

The Website 3.3 architecture-refinement cycle is accepted and complete.

The repository state published on `main`, including the finalized checkpoint status, becomes the current operational baseline.

Earlier responsibility, dependency and coupling inventories remain preserved as historical Evidence of the system before refinement. They are not rewritten retroactively.

**Checkpoint disposition:** Accepted, closed and retained as the Website 3.3 architecture-refinement baseline.
