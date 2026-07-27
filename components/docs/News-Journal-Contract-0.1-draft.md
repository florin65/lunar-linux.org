# News Journal Contract 0.1-draft

**Version:** 0.1-draft  
**Date:** 2026-07-27  
**Project:** Lunar Linux Website 3.3  
**Phase:** Componentization Phase 2 — Step 2  
**Status:** Working contract; implementation not yet accepted

## 1. Purpose

News Journal renders prepared news records into the website's established two-column journal presentation.

Its responsibility is:

> Convert an already selected and ordered news-record stream into deterministic, escaped HTML.

It does not discover, validate or archive source material.

## 2. Invocation candidate

```sh
components/news-journal.sh current prepared-news.tsv
```

or:

```sh
components/news-journal.sh archive prepared-news.tsv
```

Indentation may be supplied explicitly:

```sh
NEWS_JOURNAL_INDENT='      '   components/news-journal.sh current prepared-news.tsv
```

Contract 0.1 supports only the proven variants:

```text
current
archive
```

## 3. Prepared record format

The candidate input is UTF-8 tab-separated text, one record per line:

```text
date_display<TAB>date_datetime<TAB>category<TAB>title<TAB>href<TAB>secondary_text
```

Fields:

### `date_display`

Text shown to the user.

Example:

```text
2026-07-18 17:20
```

### `date_datetime`

Machine-readable value for the `<time datetime>` attribute.

Example:

```text
2026-07-18T17:20
```

### `category`

Human-readable news category.

### `title`

Link text for the news record.

### `href`

Prepared destination URL relative to the consuming page.

### `secondary_text`

Variant-specific supporting text.

For `current`:

```text
editorial summary
```

For `archive`:

```text
short archive object id
```

## 4. Input requirements

The input producer must ensure:

- exactly six tab-separated fields per record;
- no tab characters inside fields;
- no embedded newlines inside fields;
- non-empty date display;
- non-empty machine-readable date;
- non-empty category;
- non-empty title;
- non-empty href;
- records already appear in required output order.

The component must reject malformed records explicitly.

An empty file is valid and produces the variant's empty state.

## 5. Shared output structure

Every non-empty journal contains:

```html
<div class="community-news-journal ...">
  <table class="community-news-table ...">
    ...
    <tbody>
      <tr>
        <td class="news-meta">
          <time datetime="...">...</time>
          <span>...</span>
        </td>
        <td class="news-content">
          <a class="news-title-link" href="...">...</a>
          <p>...</p>
        </td>
      </tr>
    </tbody>
  </table>
</div>
```

Input order must be preserved.

The component does not sort records.

## 6. Current variant

Root:

```html
<div class="community-news-journal">
```

Table:

```html
<table class="community-news-table compact-news-table">
```

Header:

```html
<thead>
  <tr>
    <th>Date</th>
    <th>News</th>
  </tr>
</thead>
```

The current variant preserves the existing colgroup:

```html
<colgroup>
  <col class="community-news-col-meta">
  <col class="community-news-col-content">
</colgroup>
```

`secondary_text` is rendered as an escaped editorial summary:

```html
<p>Summary text</p>
```

Empty-file output preserves the current behavior:

```html
<div class="community-news-journal">
  <table class="community-news-table compact-news-table">
    ...
    <tbody>
    </tbody>
  </table>
  <p>No valid community or project news entries were found.</p>
</div>
```

The separate upstream case where the source directory itself is absent remains owned by the producer unless later unified intentionally.

## 7. Archive variant

Root:

```html
<div class="community-news-journal archive-journal">
```

Table:

```html
<table class="community-news-table archive-news-table">
```

`secondary_text` is the short archive object id and is rendered as:

```html
<p>Archive id: <code>030d0b5bb42c</code></p>
```

The component owns the fixed label `Archive id:` for the archive variant. The producer supplies only the identifier.

Empty-file output preserves the current behavior:

```html
<tr>
  <td colspan="2" class="news-content">No valid archived news entries were found.</td>
</tr>
```

The component does not know how the archive id was created and does not perform recovery.

## 8. Escaping

All six input fields are untrusted dynamic values for rendering purposes.

Text content must escape at least:

```text
&  <  >
```

Attribute values must escape at least:

```text
&  <  >  "  '
```

`secondary_text` is plain text. It is never interpreted as HTML.

For the archive variant, the component supplies the trusted static `<code>` framing around the escaped archive id.

## 9. Date handling

The component must not derive `date_datetime` from `date_display`.

Both are prepared input because:

- display formats may evolve;
- dates may include or omit time;
- machine-readable syntax has stricter requirements;
- archive and current producers must converge without hidden parsing inside presentation.

The component inserts:

```html
<time datetime="DATE_DATETIME">DATE_DISPLAY</time>
```

with context-appropriate escaping.

## 10. Ownership boundary

### Producer owns

- record discovery;
- source parsing;
- date validation;
- conversion to display and machine date values;
- category selection;
- title and summary extraction;
- href preparation;
- archive id preparation;
- sorting;
- article-page generation;
- archive recovery and preservation;
- reporting and counters;
- temporary-file lifecycle.

### News Journal owns

- input-shape validation;
- wrapper and table markup;
- shared row markup;
- variant classes;
- variant secondary-line presentation;
- escaping;
- preservation of input order;
- variant empty-state markup;
- writing HTML to standard output.

## 11. Failure behavior

The component exits non-zero when:

- the variant is unknown;
- the input file is missing or unreadable;
- a non-empty line does not contain exactly six fields;
- a required field is empty;
- a field contains an unsupported embedded newline representation.

Diagnostics go to standard error.

No partial HTML should be emitted for invalid input. Validation should complete before rendering begins.

## 12. Determinism

For the same:

```text
variant
input bytes
indentation
```

the component must produce identical HTML bytes.

It must not:

- read current time;
- query remote services;
- inspect Git;
- discover files outside the supplied input;
- mutate the input;
- write generated pages;
- update reports.

## 13. Direct tests

The first implementation must cover:

```text
current variant with one record
current variant with multiple records
archive variant with one record
empty current input
empty archive input
invalid variant
missing input file
wrong field count
empty required field
HTML text escaping
HTML attribute escaping
input-order preservation
```

## 14. Integration validation

For current news:

```text
old cache/community-news.html
new cache/community-news.html
→ byte comparison expected
```

For archived news:

```text
old cache/archive-news.html
new cache/archive-news.html
→ byte comparison expected
```

If byte equality is not practical because existing whitespace differs, every difference must be reviewed and explicitly accepted before integration.

A full build must then confirm:

- Info page unchanged;
- Archive page unchanged;
- News Archive page unchanged;
- article pages unchanged;
- unrelated page signatures unchanged;
- archive counters unchanged.

## 15. Non-goals

Contract 0.1 does not provide:

- arbitrary columns;
- arbitrary table headers;
- arbitrary HTML in fields;
- pagination;
- filtering;
- sorting;
- grouping by date;
- client-side behavior;
- generic table rendering;
- commit-journal support;
- icon rendering.

## 16. Implementation decision gate

Creation of `components/news-journal.sh` is justified only if the implementation:

- replaces duplicated journal markup in both producers;
- leaves data preparation in the producers;
- preserves current and archive behavior;
- is smaller and easier to test than the duplicated rendering blocks;
- introduces no new dependency.

## 17. Decision statement

The News Journal boundary is accepted as a candidate because two independent producers already generate the same semantic presentation.

The intended architecture is:

```text
current news preparation ─┐
                          ├── prepared six-field records
archive news preparation ─┘
                                   ↓
                         News Journal component
                                   ↓
                              HTML fragment
```

Implementation remains subject to direct fixture tests and generated-output comparison.
