# Website Component Inventory 0.1-draft

**Version:** 0.1-draft  
**Date:** 2026-07-27  
**Project:** Lunar Linux Website 3.3  
**Phase:** Componentization Phase 2 — Step 1  
**Status:** Working inventory; no implementation baseline

## 1. Purpose

This document records the reusable presentation units currently present in the Lunar Linux Website generator and identifies the next justified component extractions.

It is an inventory of observed implementation, not a catalogue of hypothetical abstractions.

The inventory follows the existing component rule:

> Extract only a repeated semantic responsibility whose input and output can be described more clearly than the duplicated implementation.

## 2. Current architectural boundary

The current generator contains three relevant layers:

```text
Content
  src/markdown/
  src/news/

Presentation interpretation and page composition
  tools/render-page.sh
  tools/render-news-article.sh
  templates/

Reusable presentation components
  components/
```

The renderer remains the semantic interpretation layer. A component may share a presentation contract with the renderer without requiring the renderer to execute a separate shell process for every occurrence.

## 3. Existing components

### 3.1 Archive Links

**Source:** `components/archive-links.sh`  
**Status:** Implemented and in active use  
**Responsibility:** Render a prepared ordered set of archive-related links as website buttons.

Current input:

```text
label|url
```

Current output root:

```html
<div class="hero-actions archive-section-actions archive-links">
```

Current users:

- News Archive navigation;
- Commit Archive navigation;
- Info page links to News Archive and Commit Archive.

Observed properties:

- explicit arguments;
- deterministic output;
- HTML escaping for text and attributes;
- input validation;
- optional first-button class;
- no archive selection policy inside the component.

Assessment: the component boundary is valid. It represents a specialized variant of the wider Action Links presentation unit.

### 3.2 Shared header and footer templates

**Sources:**

```text
templates/header.html
templates/footer.html
```

**Status:** Existing shared document-frame templates  
**Responsibility:** Provide common site framing.

Assessment: already shared and stable. No Phase 2 extraction is required now.

### 3.3 Page hero renderer primitive

**Source:** `render_hero()` in `tools/render-page.sh`  
**Status:** Internal renderer primitive  
**Responsibility:** Render a page hero from a prepared title, description and optional stable class variant.

Assessment: this is a valid internal component-like primitive. It does not need to become a standalone shell component. Its correct owner is the semantic renderer.

### 3.4 News section renderer primitive

**Source:** `render_news_section()` in `tools/render-page.sh`  
**Status:** Internal renderer primitive  
**Responsibility:** Compose a prepared news section from title, description, content HTML and action HTML.

Assessment: retain internally for now. It has not yet demonstrated a need for an external component interface.

## 4. Repeated semantic units observed

### 4.1 Action Links

Observed forms:

```html
<div class="hero-actions">
  <a class="button primary|secondary" href="...">...</a>
</div>
```

Locations include:

- `render_actions()` in `tools/render-page.sh`;
- `components/archive-links.sh`;
- explicit archive-page action groups in `render_archive()`;
- article return navigation in `tools/render-news-article.sh`;
- homepage and domain-page Markdown action groups rendered through `render_actions()`.

Shared semantic responsibility:

> Render an ordered group of action links using the website button language.

Stable common behavior:

- preserve order;
- first action may be primary or secondary;
- following actions are secondary;
- escape link labels and attributes;
- output no group when no links exist;
- place the group through the caller, not the component.

Assessment: confirmed next component contract. The abstraction should be semantic and HTML-contractual, not necessarily one executable implementation.

### 4.2 News Journal

Observed forms:

- current community news display;
- news archive index;
- generated news article listings.

Candidate responsibility:

> Render prepared news records as the website's news journal presentation.

Assessment: candidate only. Data shape, ordering, truncation and archive differences must be inventoried before extraction.

### 4.3 Commit Journal

Observed forms:

- Moonbase latest updates;
- commit archive index;
- archive commit rows.

Candidate responsibility:

> Render prepared commit records as the website's commit journal presentation.

Assessment: candidate only. It must remain distinct from News Journal unless later evidence proves a smaller shared primitive.

### 4.4 Generic table

Assessment: rejected for this phase.

Reason:

- news and commit tables have different semantics;
- a generic table would expose formatting mechanics rather than a domain responsibility;
- no stable general input contract has been demonstrated;
- it would move complexity instead of removing it.

## 5. Ownership decisions

### Renderer-owned internal primitives

Remain inside `tools/render-page.sh`:

- Markdown action parsing;
- page hero rendering;
- page-specific semantic composition;
- conversion of Markdown link blocks into prepared action-link records.

### Standalone component-owned rendering

Remain or become scripts under `components/` when the caller already holds prepared data:

- Archive Links;
- future News Journal, if justified;
- future Commit Journal, if justified.

### Build orchestrator responsibilities

Remain outside components:

- selecting which links appear;
- archive availability policy;
- fetching or preparing dynamic data;
- deciding page placement;
- publication and generated-file ownership.

## 6. Phase 2 extraction order

```text
1. Define Action Links Contract 0.1
2. Align Archive Links with that contract
3. Replace hard-coded action groups only where the change simplifies ownership
4. Validate byte-equivalent or intentionally equivalent HTML
5. Inventory News Journal records and variants
6. Inventory Commit Journal records and variants
```

No icon work belongs in this step. Icon selection begins only after component boundaries and accessible link semantics are stable.

## 7. Non-goals

This phase does not introduce:

- a component registry;
- a plugin system;
- a templating framework;
- a generic widget library;
- a generic table component;
- shell subprocess calls from AWK for every action group;
- a rewrite of `tools/render-page.sh`;
- visual redesign;
- icon integration.

## 8. Validation rule

Every extraction must demonstrate:

```text
same semantic input
→ predictable component output
→ no hidden policy
→ no unrelated page changes
→ less duplication or clearer ownership
```

The default expectation for the first Action Links step is no user-visible HTML or CSS change.

## 9. Inventory conclusion

The current implementation supports one immediate formalization:

```text
Action Links
```

Archive Links is a specialized Action Links variant already proven in production. News Journal and Commit Journal remain candidates awaiting a focused record-and-variant inventory.
