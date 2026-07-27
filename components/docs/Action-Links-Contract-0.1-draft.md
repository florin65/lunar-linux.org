# Action Links Contract 0.1-draft

**Version:** 0.1-draft  
**Date:** 2026-07-27  
**Project:** Lunar Linux Website 3.3  
**Phase:** Componentization Phase 2 — Step 1  
**Status:** Working contract; no output change authorized by this document

## 1. Purpose

Action Links is the website presentation unit for an ordered group of links rendered with the existing button language.

Its responsibility is limited to:

> Render prepared actions as accessible HTML links with deterministic classes and order.

It does not select actions, interpret page policy or determine placement.

## 2. Semantic input

An Action Links group receives:

- zero or more ordered action records;
- a first-action presentation class;
- an optional stable group variant;
- indentation required by the caller.

Each action record contains:

```text
label
url
```

The current shell representation may remain:

```text
label|url
```

The representation is an implementation detail. The semantic contract is the pair `(label, url)`.

## 3. Input requirements

For every action:

- `label` must not be empty;
- `url` must not be empty;
- input order is significant;
- labels are plain text unless the renderer explicitly owns inline-Markdown interpretation;
- URLs are prepared by the caller;
- the component does not test remote availability;
- the component does not infer root prefixes or page ownership unless explicitly passed as prepared input.

Malformed input must fail explicitly in standalone script implementations.

## 4. Presentation rules

The common group class is:

```html
<div class="hero-actions">
```

The first action class is selected by the caller:

```text
primary
secondary
```

Every later action uses:

```text
secondary
```

Link classes are:

```html
class="button primary"
```

or:

```html
class="button secondary"
```

## 5. Group variants

A stable semantic variant may add classes to the common root.

The currently proven variant is Archive Links:

```html
<div class="hero-actions archive-section-actions archive-links">
```

Variant rules:

- `hero-actions` is always present;
- additional classes describe semantic purpose or stable placement behavior;
- variants do not select link content;
- variants do not change link order;
- variants are added only after observed repeated need.

No generic `custom class` escape hatch is part of Contract 0.1. A caller-specific arbitrary class would weaken the semantic boundary.

## 6. Output contract

For input:

```text
Download|pages/download.html
Documentation|pages/docs.html
Latest News|pages/info.html
```

with first action `primary`, the renderer-owned Markdown implementation currently normalizes the `pages/` prefix and produces:

```html
<div class="hero-actions">
  <a class="button primary" href="download.html">Download</a>
  <a class="button secondary" href="docs.html">Documentation</a>
  <a class="button secondary" href="info.html">Latest News</a>
</div>
```

For the Archive Links variant:

```text
News Archive →|news-archive.html
```

with first action `secondary`, output is:

```html
<div class="hero-actions archive-section-actions archive-links">
  <a class="button secondary" href="news-archive.html">News Archive →</a>
</div>
```

Zero actions produce no output.

## 7. Escaping

Dynamic values must be escaped according to HTML context.

Label text escapes at least:

```text
&  <  >
```

URL attributes escape at least:

```text
&  <  >  "  '
```

The semantic renderer may support inline formatting in labels when that behavior already belongs to its Markdown contract. A standalone component receiving plain labels must not interpret markup.

This difference is allowed because both implementations share the Action Links semantic contract while retaining their correct parsing ownership.

## 8. URL normalization

URL normalization belongs to the layer that understands source context.

Current renderer behavior:

```text
pages/example.html
→ example.html
```

This is Markdown/page-source normalization and remains owned by `tools/render-page.sh`.

A standalone Action Links or Archive Links component receives the final prepared URL and must not silently remove path prefixes.

## 9. Accessibility

Action Links uses real `<a>` elements.

Requirements:

- labels must describe the destination or action meaningfully;
- keyboard behavior remains native;
- no information may depend only on primary/secondary color;
- decorative icons added later must not replace link text;
- an icon-only action is outside Contract 0.1.

## 10. Ownership boundary

### Caller owns

- action selection;
- order;
- labels and destination meaning;
- path preparation;
- page placement;
- archive or domain policy;
- whether the first action is primary or secondary;
- whether the stable Archive Links variant applies.

### Action Links owns

- group framing;
- link classes;
- deterministic order preservation;
- context-appropriate escaping;
- empty-input behavior;
- validation in standalone implementations.

## 11. Implementation model

Contract 0.1 permits more than one implementation when ownership requires it.

### Renderer implementation

`render_actions()` in `tools/render-page.sh` remains an internal AWK implementation because it:

- receives link records produced by the Markdown parser;
- may render inline Markdown labels;
- performs source-context URL normalization;
- avoids spawning a shell process for every group.

### Standalone implementation

`components/archive-links.sh` remains a shell implementation for prepared build-generated links.

A future `components/action-links.sh` is justified only when at least one additional standalone caller needs the common behavior and its introduction reduces code rather than merely renaming Archive Links.

This contract does not require creating that file immediately.

## 12. Migration rule

A hard-coded action group should migrate only when all are true:

1. the links are already prepared outside the markup block;
2. migration reduces duplication or clarifies ownership;
3. output remains equivalent;
4. no page-specific policy moves into the component;
5. the resulting invocation is easier to understand than the original HTML.

The two hard-coded complete-archive links in `render_archive()` are candidates for later alignment, but Contract 0.1 does not authorize a mechanical replacement before the placement and source-context behavior are reviewed.

The single return action in `tools/render-news-article.sh` shares the presentation language but does not by itself justify invoking a separate component process.

## 13. Validation

Validation for an implementation change must include:

```text
shell syntax check
standalone invalid-input tests
HTML escaping test
zero-input test
first-class primary test
first-class secondary test
generated HTML comparison
browser inspection
unrelated-page signature comparison
```

Expected result for Step 1:

```text
contract introduced
inventory recorded
HTML output unchanged
```

## 14. Evolution triggers

Contract 0.1 may grow only after observed need for one of the following:

- disabled actions;
- external-link semantics;
- accessible icons;
- additional stable group variants;
- structured-file input for many actions;
- a second standalone caller proving the need for `components/action-links.sh`.

Until then, these remain outside the contract.

## 15. Decision statement

Action Links is a shared semantic presentation contract.

It is not required to be a single executable component in every rendering path.

The correct Phase 2 design is:

```text
shared semantic contract
├── renderer-owned AWK implementation
└── standalone Archive Links implementation
```

This preserves component consistency without adding subprocess coupling or a premature component framework.
