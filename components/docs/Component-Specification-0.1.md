# Website Component Specification 0.1

**Version:** 0.1  
**Date:** 2026-07-12  
**Status:** Draft baseline for implementation  
**Project:** Lunar Linux Website 3.2 — The Next Generation

## 1. Purpose

This document defines the minimum contract for reusable website components.

It exists to guide incremental extraction from the current generator.

The specification is intentionally small.

It does not attempt to create a general component framework.

It defines only what is needed to remove real duplication while preserving the static, transparent and inspectable nature of the website.

## 2. Definition

A component is a reusable presentation unit with:

- one clear responsibility;
- a stable input;
- predictable HTML output;
- no hidden data acquisition;
- no page-specific assumptions unless explicitly declared;
- a name that describes its semantic role.

Examples:

```text
Archive Links
Footer
Navigation
News Journal
Moonbase Commit Journal
```

## 3. What is not a component

The following are not components by default:

- an entire page;
- a one-off HTML fragment used once;
- a CSS class;
- a data-fetching script;
- a page-name conditional;
- a workaround for incorrect markup;
- a collection of unrelated HTML lines;
- an abstraction created only because it might be useful later.

A component must represent a real repeated responsibility.

## 4. Extraction criteria

A component should be extracted only when all of the following are true:

1. the same semantic unit appears in more than one place, or is clearly becoming shared;
2. its responsibility can be named precisely;
3. its input can be described;
4. its output is stable;
5. extraction removes duplication or page-specific branching;
6. the component is easier to understand than the repeated implementation;
7. the current manual pattern has already been observed and validated.

This follows the project rule:

> Manual first. Extract after repetition is understood.

## 5. Responsibility boundary

A component should do one job.

Good examples:

```text
render a group of archive links
render the global footer
render the global navigation
render a news table from prepared news data
```

Bad examples:

```text
render the page and update remote data
render navigation and decide archive policy
render a footer and parse Markdown
```

A component may format prepared data.

It should not fetch, discover or mutate external data unless that behavior is explicitly part of a separate provider or build step.

## 6. Input contract

Each component must document its input.

Possible input forms include:

- arguments;
- environment variables;
- a prepared text file;
- a structured temporary file;
- a template;
- Markdown metadata;
- generated JSON already prepared by another build step.

Inputs must be explicit.

A component must not depend silently on unrelated global variables when those dependencies can be passed clearly.

## 7. Output contract

A rendering component outputs HTML.

Its output must be:

- deterministic for the same input;
- valid within the intended page context;
- free of full-document framing unless the component is specifically the document frame;
- independent of remote services;
- suitable for insertion into the generated page.

A component must not write directly into unrelated output files unless its contract explicitly defines that file as its output.

## 8. File location

Reusable components should be stored under:

```text
components/
```

The initial structure may remain simple:

```text
components/
├── archive-links.sh
├── footer.html
└── navigation.html
```

Subdirectories should be added only when the number or type of components makes them useful.

Do not create deep hierarchy in advance.

## 9. Naming

Component names should describe semantic purpose.

Preferred:

```text
archive-links
navigation
footer
news-journal
commit-journal
```

Avoid:

```text
helper1
common-block
generic-widget
misc
page-fragment
```

Shell component files should use lowercase names with hyphens:

```text
archive-links.sh
news-journal.sh
```

Static HTML component templates should use:

```text
navigation.html
footer.html
```

## 10. Invocation

A component should have one obvious invocation path.

Examples:

```sh
components/archive-links.sh \
  "News Archive|news-archive.html" \
  "Commit Archive|commits-archive.html"
```

or:

```sh
render_component archive-links "$prepared_links_file"
```

The final invocation style should be chosen from the simplest pattern that fits the current generator.

A generic component registry is not required for version 0.1.

## 11. Composition

Components are composed by the generator.

The component should not decide where it belongs in the page.

The page renderer or page composition layer remains responsible for placement.

Example:

```text
page renderer
    │
    ├── render page section
    ├── insert Archive Links component
    └── continue page rendering
```

## 12. Data preparation

Data preparation and HTML rendering should remain distinct where practical.

Example:

```text
archive policy
     ↓
prepared archive link list
     ↓
Archive Links component
     ↓
HTML
```

The component receives the already selected links.

It does not decide which domain owns which archive.

That policy belongs to the page or generator logic.

## 13. Escaping

All component-generated text values must be escaped correctly for their HTML context.

At minimum:

- text content must escape `&`, `<` and `>`;
- attribute values must also escape quotes;
- URLs must be inserted only after appropriate attribute escaping.

Static trusted template markup does not require runtime escaping.

Dynamic content does.

## 14. CSS contract

A component should expose meaningful classes.

Example:

```html
<div class="hero-actions archive-section-actions archive-links">
  <a class="button secondary" href="news-archive.html">News Archive</a>
</div>
```

CSS classes should express purpose, not implementation accidents.

Preferred:

```text
archive-links
site-navigation
site-footer
news-journal
```

Avoid:

```text
left-blue-box-2
special-page-links
temporary-row
```

Components should reuse the existing visual language before introducing new styles.

## 15. Accessibility

Components must preserve basic accessibility.

Depending on the component, this includes:

- semantic elements;
- meaningful link text;
- appropriate navigation labels;
- valid heading relationships;
- keyboard-accessible links and controls;
- no information conveyed only by color.

Navigation components should use:

```html
<nav aria-label="Main navigation">
```

## 16. Page independence

A component should not hard-code the current page name unless that is part of its explicit contract.

For root-relative differences, a component may accept:

```text
root prefix
current path
target path
```

The existing `{{root}}` approach may continue where it remains sufficient.

## 17. No hidden page exceptions

A component must not contain logic such as:

```text
if page == X, change unrelated behavior
```

Page-specific selection belongs outside the component.

A component may receive a variant only when the variant represents a stable, named presentation difference.

Example:

```text
archive-links compact
archive-links standard
```

Even then, variants should be added only after repeated need is observed.

## 18. Testing

Each new component should be validated through:

1. generated HTML inspection;
2. browser inspection;
3. link verification;
4. responsive inspection when layout is affected;
5. comparison with the previous output;
6. confirmation that unrelated pages remain unchanged.

For script components, a direct invocation test is recommended when possible.

## 19. Generated output rule

Components are source.

Their generated HTML output is not authoritative.

The workflow remains:

```text
edit component source
        ↓
run generator
        ↓
inspect generated HTML
        ↓
commit source and deployment output
```

Generated pages must not be used as the long-term editing surface.

## 20. First component: Archive Links

The first component will represent grouped links from a domain page to its archives.

Examples:

```text
Info
 ├── News Archive
 └── Commit Archive

Docs
 └── Documentation Archive

LUR
 └── Crater
```

The component responsibility is:

> Render a prepared set of archive-related links using the website's existing button presentation.

The component does not decide:

- what counts as an archive;
- which domain owns an archive;
- link order;
- archive availability;
- archive generation.

Those decisions remain with the page or generator logic.

## 21. Initial Archive Links contract

### Input

A sequence of:

```text
label|url
```

Example:

```text
News Archive|news-archive.html
Commit Archive|commits-archive.html
```

### Output

```html
<div class="hero-actions archive-section-actions archive-links">
  <a class="button secondary" href="news-archive.html">News Archive</a>
  <a class="button secondary" href="commits-archive.html">Commit Archive</a>
</div>
```

### Requirements

- preserve input order;
- escape labels and URLs;
- output nothing for an empty input set;
- use existing button classes;
- add only the semantic `archive-links` class;
- contain no domain policy.

## 22. Initial implementation strategy

The first implementation should be small.

A shell function or standalone shell script is sufficient.

Do not introduce:

- a component registry;
- a plugin system;
- a new configuration language;
- a general templating engine;
- a new build dependency;
- a rewrite of the renderer.

The purpose of the first component is to validate the boundary.

## 23. Evolution

Version 0.1 may be revised after the first components are implemented.

Changes should be based on observed needs such as:

- repeated input handling;
- repeated escaping;
- repeated component invocation;
- clear need for shared component helpers;
- clear need for component metadata.

The specification should not grow ahead of implementation.

## 24. Baseline statement

A Website 3.2 component is a small, explicit and reusable presentation unit extracted from real repetition.

It receives prepared input.

It produces predictable HTML.

It owns one responsibility.

It introduces less complexity than the duplication it replaces.
