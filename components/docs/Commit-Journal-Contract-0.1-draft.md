# Commit Journal Contract 0.1-draft

**Version:** 0.1-draft  
**Date:** 2026-07-27  
**Project:** Lunar Linux Website 3.3  
**Phase:** Componentization Phase 2 — Step 3  
**Status:** Working contract; implementation not yet accepted

## 1. Purpose

Commit Journal renders prepared Lunar Moonbase commit records into the established four-column HTML journal.

Its responsibility is:

> Convert an already selected and ordered commit-record stream into deterministic, escaped HTML.

It does not parse source JSON, inspect Git or manage archive material.

## 2. Invocation candidate

```sh
components/commit-journal.sh current prepared-commits.tsv
```

or:

```sh
components/commit-journal.sh archive prepared-commits.tsv
```

Indentation may be supplied through:

```sh
COMMIT_JOURNAL_INDENT='      '   components/commit-journal.sh current prepared-commits.tsv
```

Contract 0.1 supports only:

```text
current
archive
```

## 3. Prepared record format

The input is UTF-8 tab-separated text, one record per line:

```text
commit<TAB>repository<TAB>module<TAB>summary<TAB>link_title
```

Fields:

### `commit`

Complete commit identifier shown as the link text.

### `repository`

Moonbase repository suffix.

Example:

```text
other
```

The resulting repository name is:

```text
moonbase-other
```

### `module`

Prepared module name shown in the Module column.

### `summary`

Prepared commit comment shown in the Comment column.

### `link_title`

Optional title attribute for the commit link.

For `current` this field is empty.

For `archive` this field contains the archived date.

## 4. Input requirements

Every non-empty record must contain exactly five tab-separated fields.

Required non-empty fields:

```text
commit
repository
module
summary
```

`link_title` may be empty.

The input producer must ensure:

- no embedded tab characters in fields;
- no embedded newlines in fields;
- commit and repository values are safe prepared scalar values;
- module and summary fallbacks have already been resolved;
- records are already in required output order.

An empty file is valid and produces the variant-specific empty state.

The component must validate the complete input before writing HTML.

## 5. URL construction

The component constructs the destination as:

```text
https://github.com/lunar-linux/moonbase-<repository>/commit/<commit>
```

Both `repository` and `commit` are inserted into the URL and then escaped for an HTML attribute.

Contract 0.1 is intentionally Lunar Moonbase-specific.

## 6. Shared columns

Both variants render:

```text
Commit
Repository
Module
Comment
```

Shared cell classes:

```text
commit-id
repository-name
module-name
commit-comment
```

Shared link attributes:

```html
target="_blank" rel="noopener"
```

Input order is preserved.

The component does not sort.

## 7. Current variant

Root:

```html
<div class="moonbase-journal">
```

Table:

```html
<table class="moonbase-table">
```

The current colgroup is preserved:

```html
<colgroup>
  <col class="moonbase-col-commit">
  <col class="moonbase-col-repository">
  <col class="moonbase-col-module">
  <col class="moonbase-col-comment">
</colgroup>
```

Header markup remains expanded:

```html
<thead>
  <tr>
    <th>Commit</th>
    <th>Repository</th>
    <th>Module</th>
    <th>Comment</th>
  </tr>
</thead>
```

Rows remain expanded across separate lines.

When `link_title` is empty, the commit link must not contain a `title` attribute.

Empty input preserves:

```html
<p>No Moonbase commits were found for the selected period.</p>
```

after the table.

## 8. Archive variant

Root:

```html
<div class="moonbase-journal archive-journal">
```

Table:

```html
<table class="moonbase-table archive-commits-table">
```

The archive header remains compact:

```html
<thead><tr><th>Commit</th><th>Repository</th><th>Module</th><th>Comment</th></tr></thead>
```

Each archive record remains one compact table-row line.

When `link_title` is non-empty, it is emitted as:

```html
title="..."
```

Empty input preserves:

```html
<tr><td colspan="4" class="commit-comment">No archived commits were found.</td></tr>
```

## 9. Escaping

Text content must escape at least:

```text
&  <  >
```

Attribute values must escape at least:

```text
&  <  >  "  '
```

Dynamic values include:

```text
commit
repository
module
summary
link_title
constructed href
```

No input field is interpreted as HTML.

## 10. Ownership boundary

### Producer owns

- source discovery;
- JSON parsing;
- JSON decoding;
- category filtering;
- archive decompression;
- required-field validation at source level;
- module fallback;
- summary fallback;
- tab normalization or rejection;
- record selection;
- record ordering;
- statistics;
- archive warnings and reports;
- temporary-file lifecycle outside component invocation.

### Commit Journal owns

- prepared-record shape validation;
- variant validation;
- URL construction;
- wrapper and table markup;
- current colgroup;
- shared column headings;
- row markup;
- optional link title;
- HTML escaping;
- variant classes;
- variant empty state;
- preservation of input order;
- writing HTML to standard output.

## 11. Failure behavior

The component exits non-zero when:

- invocation arity is invalid;
- the variant is unknown;
- the input file is missing or unreadable;
- a non-empty line does not contain exactly five fields;
- one of the four required fields is empty.

Diagnostics go to standard error.

No partial HTML should be emitted for invalid input.

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
- query GitHub;
- inspect Git;
- read source JSON;
- discover archive files;
- sort records;
- mutate files;
- write reports;
- generate pages.

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
empty optional link_title
non-empty archive link_title
text escaping
attribute escaping
URL construction
input-order preservation
no partial output on validation failure
```

## 14. Integration validation

### Current journal

Because the current fragment is generated in a temporary file inside `build-site.sh`, validation should compare one of:

```text
captured old temporary fragment
captured new temporary fragment
```

or:

```text
affected generated page before extraction
affected generated page after extraction
```

The expected result is byte equality.

### Archive journal

```text
old cache/archive-commits.html
new cache/archive-commits.html
→ byte comparison expected
```

A full build must then confirm:

- active Moonbase commit page output unchanged;
- archive commit page output unchanged;
- archive counters unchanged;
- unrelated page signatures unchanged;
- no additional warnings.

## 15. Non-goals

Contract 0.1 does not provide:

- arbitrary columns;
- arbitrary headers;
- arbitrary repository hosts;
- arbitrary organizations;
- generic Git providers;
- sorting;
- filtering;
- pagination;
- commit statistics;
- archive reading;
- JSON parsing;
- client-side behavior;
- generic table rendering;
- News Journal support;
- icon rendering.

## 16. Implementation decision gate

Creation of `components/commit-journal.sh` is justified only if it:

- replaces duplicated commit-table markup in both producers;
- leaves source and archive preparation in their existing owners;
- preserves current and archive output;
- introduces no new dependency;
- remains simpler to test than the duplicated renderers;
- does not become a general table abstraction.

## 17. Decision statement

The intended architecture is:

```text
current Moonbase preparation ─┐
                              ├── prepared five-field records
archive commit preparation ───┘
                                       ↓
                            Commit Journal component
                                       ↓
                                  HTML fragment
```

Contract 0.1 deliberately captures the proven Lunar Moonbase use case and nothing broader.
