# News Journal Inventory 0.1-draft

**Version:** 0.1-draft  
**Date:** 2026-07-27  
**Project:** Lunar Linux Website 3.3  
**Phase:** Componentization Phase 2 — Step 2  
**Status:** Working inventory; no implementation baseline

## 1. Purpose

This document records the current news-journal implementations and the differences that must remain visible before any extraction.

It is based on the active website generator and its generated fragments. It does not assume that current news and archived news are identical components.

## 2. Current implementations

### 2.1 Current News Journal

**Producer:** `tools/build-community-news.sh`  
**Generated fragment:** `cache/community-news.html`  
**Consumer:** Info page through `{{ community_news_html }}`

Root structure:

```html
<div class="community-news-journal">
  <table class="community-news-table compact-news-table">
```

Prepared record fields:

```text
date
date_html
date_short
category
title
summary
href
```

Visible row content:

```text
Date and optional time
Category
Linked title
Editorial summary
```

Additional responsibilities currently held by the producer:

- parse and validate news source metadata;
- validate real calendar dates;
- derive a slug;
- prevent slug collisions;
- derive the first non-empty body line as summary;
- render current article pages;
- publish and clean the article-page manifest;
- sort records newest first;
- render the journal fragment.

Assessment: data preparation, page generation and journal rendering currently coexist in one script.

### 2.2 Archived News Journal

**Producer:** `tools/build-archive-index.sh`, function `build_news_fragment()`  
**Generated fragment:** `cache/archive-news.html`  
**Consumers:** general Archive page and dedicated News Archive page through `{{ archive_news_html }}`

Root structure:

```html
<div class="community-news-journal archive-journal">
  <table class="community-news-table archive-news-table">
```

Prepared record fields:

```text
date
category
title
slug
archive object id
public archive path
```

Visible row content:

```text
Date and optional time
Category
Linked title
Short archive object id
```

Additional responsibilities currently held by the producer:

- read preserved archive objects;
- recover source material when possible;
- preserve previous HTML on recoverable failures;
- generate archive article pages;
- report generated, preserved, skipped and warning counts;
- sort records newest first;
- render the journal fragment.

Assessment: this is an archive-aware producer. Its recovery and preservation responsibilities must not move into a presentation component.

## 3. Shared semantic structure

Both journals render an ordered sequence of news records with:

```text
date
category
title
href
secondary line
```

Both use the same semantic CSS language:

```text
community-news-journal
community-news-table
news-meta
news-content
news-title-link
```

Both produce:

```html
<tr>
  <td class="news-meta">...</td>
  <td class="news-content">...</td>
</tr>
```

Both sort newest first before rendering.

This confirms a real repeated presentation responsibility.

## 4. Important differences

### Current journal

```text
variant class: compact-news-table
secondary line: editorial summary
empty state: paragraph after an empty tbody
colgroup: explicit metadata/content columns
```

### Archive journal

```text
variant classes: archive-journal + archive-news-table
secondary line: archive id
empty state: table row with colspan=2
colgroup: absent
archive recovery: part of upstream preparation
```

These differences are not incidental. The secondary line represents different semantics:

```text
current news
→ what the news is about

archived news
→ preserved identity of the archived record
```

## 5. Current duplication

The duplicated presentation responsibilities are:

- journal wrapper;
- table framing;
- two-column header;
- row framing;
- news metadata cell;
- title link;
- secondary text line;
- empty-state presentation;
- HTML escaping around prepared values.

The non-duplicated responsibilities are:

- source parsing;
- source validation;
- slug generation;
- current article publication;
- archive recovery;
- archive preservation policy;
- archive reporting;
- selection of secondary-line meaning.

## 6. Candidate component boundary

The justified candidate is:

```text
News Journal
```

Proposed responsibility:

> Render prepared news records using the website news-journal presentation, with a small set of proven semantic variants.

The component may own:

- wrapper and table markup;
- shared row structure;
- HTML escaping;
- deterministic record order preservation;
- variant-specific classes;
- variant-specific secondary-line label or markup;
- empty-state rendering.

The component must not own:

- file discovery;
- Markdown parsing;
- date validation;
- slug generation;
- sorting policy unless the input contract explicitly requires already sorted records;
- article-page generation;
- archive recovery;
- archive object identity generation;
- build-report mutation.

## 7. Input strategy under evaluation

Passing all records as shell arguments is rejected. News values may contain spaces, punctuation and future delimiters.

The simplest robust current option is a prepared tab-separated file with one record per line.

Candidate shared fields:

```text
date_display<TAB>date_datetime<TAB>category<TAB>title<TAB>href<TAB>secondary_text
```

The caller remains responsible for preparing safe field values and rejecting tab characters where required.

The component remains responsible for HTML escaping.

This representation is not yet accepted as baseline. It must be tested against both current and archive producers.

## 8. Candidate variants

Only two variants are currently proven:

```text
current
archive
```

### `current`

- root class: `community-news-journal`;
- table classes: `community-news-table compact-news-table`;
- secondary line: editorial summary;
- optional current colgroup.

### `archive`

- root classes: `community-news-journal archive-journal`;
- table classes: `community-news-table archive-news-table`;
- secondary line: archive identifier;
- archive-specific empty state.

A generic arbitrary-class interface is not justified.

## 9. Empty states

Current implementations disagree on empty-state markup.

Before extraction, one of two decisions must be made:

```text
preserve each variant byte-for-byte
```

or:

```text
adopt one intentionally shared empty-state contract
```

For the first implementation, preservation is safer. Visual normalization can be evaluated separately.

## 10. Date semantics

The current journal correctly normalizes a date with time for the `datetime` attribute:

```text
2026-07-18 17:20
→ 2026-07-18T17:20
```

The archive journal currently writes the display value directly into `datetime`:

```html
<time datetime="2026-07-18 17:20">
```

That value is not the same format used by the current journal.

This should be treated as a separate correctness observation, not silently changed during component extraction. The future prepared input should provide distinct display and machine-readable date values.

## 11. CSS ownership

The existing CSS already expresses a shared News Journal presentation language.

No new visual design is required for extraction.

The first implementation should reuse:

```text
community-news-journal
community-news-table
compact-news-table
archive-journal
archive-news-table
news-meta
news-content
news-title-link
```

CSS consolidation is outside Step 2 unless extraction reveals a real conflict.

## 12. Recommended extraction path

```text
1. Define News Journal Contract 0.1-draft
2. Implement components/news-journal.sh against prepared TSV records
3. Test the component directly with current and archive fixtures
4. Change build-community-news.sh to prepare records and invoke the component
5. Compare cache/community-news.html before and after
6. Change build-archive-index.sh to invoke the same component in archive variant
7. Compare cache/archive-news.html before and after
8. Run full build and compare page signatures
```

Each producer retains its current data acquisition and policy responsibilities.

## 13. Risks

Primary risks:

- tabs or newlines entering fields;
- accidental reordering;
- changing whitespace in generated fragments and triggering broad signatures;
- changing archive empty-state behavior;
- losing the distinct machine-readable date value;
- moving archive recovery policy into the component;
- over-generalizing the secondary line.

## 14. Inventory conclusion

A shared News Journal component is justified.

The correct boundary is narrower than either current producer:

```text
prepared records
→ News Journal renderer
→ HTML fragment
```

The producers remain responsible for turning source or archive material into prepared records.
