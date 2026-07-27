# Lunar Linux Website Architecture

**Version:** 0.1
**Date:** 2026-07-27
**Status:** Current architecture baseline
**Project:** Lunar Linux Website 3.3

## 1. Purpose

This document describes the current architecture of the Lunar Linux website generator.

It records how the system works now, where responsibilities are located, which files are authoritative, and which boundaries must be preserved while the generator evolves.

The goal is not to design a theoretical framework.

The goal is to document the real system well enough that it can be improved without losing its simplicity, transparency or existing behavior.

## 2. Architectural identity

The website is a static publishing system built around:

- Markdown source files;
- shell and `awk` generation tools;
- reusable templates;
- generated HTML;
- Git as the source of truth;
- GitHub Pages as the public deployment target.

The architecture follows the same principles as Lunar Linux:

- simple;
- inspectable;
- maintainable;
- close to standard tools;
- automated only where automation provides clear value.

## 3. Source of truth

The authoritative project state is stored in Git.

The repository contains both source material and generated public output.

The primary source areas are:

```text
src/markdown/
src/news/
templates/
components/
tools/
site.conf
```

The generated public website is stored in:

```text
docs/
```

Files under `docs/` are deployment output.

They may be committed because GitHub Pages publishes from that directory, but they are not the preferred editing surface when an authoritative source exists elsewhere.

## 4. High-level structure

```text
Markdown + data + templates
            │
            ▼
     build-site.sh
            │
            ├── dynamic data update
            ├── news index generation
            ├── archive update
            ├── variable expansion
            ├── semantic page rendering
            ├── prepared fragment rendering
            └── page composition
            │
            ▼
        docs/*.html
            │
            ▼
       GitHub Pages
```

## 5. Main directories

### `src/markdown/`

Contains the source content for the main website pages.

Each Markdown file may include front matter such as:

```text
title
description
layout
permalink
```

The body is interpreted by the page renderer and transformed into page sections.

Examples include:

```text
index.md
about.md
download.md
docs.md
info.md
lur.md
lss.md
```

### `src/news/`

Contains editorial news entries.

Each file uses a simple metadata header:

```text
Date:
Category:
Title:
```

The file body provides the summary and article content.

These files are used to generate:

```text
docs/data/news.json
docs/info.html
docs/news/*.html
```

### `templates/`

Contains shared HTML templates.

Current important files include:

```text
templates/header.html
templates/footer.html
templates/pages/
```

The shared header and footer are inserted into generated pages.

Page templates provide page-specific composition hooks where required.

### `components/`

Contains small standalone presentation components with explicit semantic contracts.

Current components include:

```text
components/archive-links.sh
components/news-journal.sh
components/commit-journal.sh
components/tests/
components/docs/
```

Components receive prepared input and emit deterministic HTML fragments.

They do not discover source material, choose ordering policy, recover archives, publish pages or update build reports.

### `tools/`

Contains the generator and support utilities.

Important files include:

```text
tools/build-site.sh
tools/render-page.sh
tools/archive.sh
tools/build-archive-index.sh
tools/build-community-news.sh
tools/build-moonbase-news.sh
tools/count-moonbase.sh
tools/get-iso-file-date.sh
```

### `docs/`

Contains generated public output.

It includes:

- HTML pages;
- news articles;
- CSS and visual assets;
- generated JSON data;
- published archives.

GitHub Pages serves this directory.

## 6. Build entry point

The main build entry point is:

```text
tools/build-site.sh
```

Its responsibilities currently include:

1. loading configuration;
2. resolving project paths;
3. updating dynamic data;
4. generating the news index;
5. updating archives;
6. publishing archive assets;
7. loading dynamic values;
8. preparing generated fragments;
9. preparing dynamic and archive fragments;
10. rendering Markdown pages;
11. composing the final HTML document;
12. generating compatibility redirects;
13. finalizing build state and maintenance reports;
14. cleaning temporary files.

This file is functional but carries several responsibilities.

Future cleanup should separate responsibilities incrementally, without introducing unnecessary abstractions or breaking the current workflow.

## 7. Page renderer

The page renderer is:

```text
tools/render-page.sh
```

It transforms interpreted Markdown blocks into HTML page content.

Its current responsibilities include:

- parsing headings;
- generating heading IDs;
- parsing paragraphs;
- parsing ordered and unordered lists;
- parsing quotations;
- parsing links;
- parsing fenced code blocks;
- accepting HTML blocks;
- supporting include markers;
- selecting page-specific rendering functions;
- rendering generic content sections;
- rendering specialized page layouts.

The renderer already acts as the semantic interpretation layer of the website.

It should remain responsible for translating content meaning into HTML structure.

It should not become responsible for dynamic data acquisition or deployment.

## 8. Content model

The current content model contains several distinct classes.

### Main pages

Stored in:

```text
src/markdown/
```

These represent stable domains such as:

```text
Home
About
Info
Download
Docs
LUR
Community
Development
LSS
```

### Editorial news

Stored in:

```text
src/news/
```

These represent dated project or community information.

### Dynamic project data

Stored or generated under:

```text
docs/data/
cache/
archive/
```

Examples include:

- Moonbase statistics;
- latest daily ISO information;
- Moonbase commit activity;
- news indexes;
- historical commit and news archives.

### Shared presentation

Stored in:

```text
templates/
docs/css/
docs/assets/
```

These define common page framing and visual presentation.

## 9. Information architecture

Website 3.3 uses domain ownership instead of a central Archive domain.

The current top-level navigation is:

```text
Home
About
Info
Download
Docs
LUR
Community
Development
```

Archives belong to their domains:

```text
Info
 ├── News Archive
 └── Commit Archive

Docs
 └── Documentation Archive

LUR
 └── Crater and future historical collections
```

This distinction is architectural, not cosmetic.

Archive is a temporal dimension of a domain, not a domain itself.

## 10. News generation flow

```text
src/news/*.md
      │
      ▼
build_news_json()
      │
      ▼
docs/data/news.json
      │
      ├── Info index
      ├── individual news pages
      └── news archive
```

The JSON index is generated output.

It must not be edited manually.

The Markdown files in `src/news/` are the authoritative editorial sources.

## 11. Dynamic data flow

Dynamic data is updated only when enabled by configuration or environment variables.

Important switches include:

```text
UPDATE_DYNAMIC_DATA
UPDATE_ARCHIVE
GENERATE_NEWS_JSON
```

This permits two useful build modes.

### Full refresh

Used when current remote or repository activity should be incorporated.

### Stable local regeneration

Used when testing layout or content without changing dynamic data.

Example:

```sh
UPDATE_DYNAMIC_DATA=no \
UPDATE_ARCHIVE=no \
GENERATE_NEWS_JSON=no \
./tools/build-site.sh
```

The distinction is important because content changes should not be mixed unnecessarily with unrelated dynamic refreshes.

## 12. Page composition

The final HTML page is composed from:

```text
HTML head
shared header
rendered page body
shared footer
closing document markup
```

The composition step belongs to `build-site.sh`.

The semantic page body belongs to `render-page.sh`.

Prepared repeated presentation records may be rendered by standalone components under `components/`.

The established boundary is:

```text
source or archive material
        ↓
producer validation and policy
        ↓
prepared ordered records
        ↓
deterministic component renderer
        ↓
HTML fragment
```

This separation should be preserved.

## 13. Redirects

Compatibility redirects are generated for retired public entry points.

Current redirects include:

```text
news.html    -> info.html
archive.html -> info.html
```

Redirects preserve compatibility while allowing the information architecture to evolve.

They are generated artifacts and should not be maintained as independent hand-written pages.

## 14. CSS responsibility

CSS defines the visual language of the website.

It should control:

- typography;
- spacing;
- layout;
- colors;
- component presentation;
- responsive behavior;
- link visibility;
- tables;
- cards;
- navigation;
- documentation readability.

CSS should not compensate for incorrect semantic HTML.

When a page requires unusual CSS to behave correctly, the HTML structure and rendering responsibility should be checked first.

## 15. Generated-file rule

When a source file exists, generated HTML must not be edited manually.

The normal workflow is:

```text
edit source
      ↓
run generator
      ↓
inspect output
      ↓
commit source + generated output
```

Manual changes in generated files create divergence and are overwritten by the next build.

## 16. Current architectural strengths

The existing system already provides:

- a complete static-site build;
- simple source formats;
- no heavyweight runtime;
- deterministic local generation;
- inspectable shell tools;
- a semantic renderer;
- small deterministic presentation components;
- direct fixture tests for journal components;
- incremental page signatures and build-state maintenance;
- dynamic project data;
- generated news and archives;
- compatibility redirects;
- GitHub Pages deployment;
- progressive improvement without framework lock-in.

## 17. Current architectural limits

The current system also has real limits:

- `build-site.sh` remains the main orchestration point and still owns several responsibilities;
- `render-page.sh` contains page-specific semantic rendering paths;
- some behavior is selected by page name;
- standalone components currently cover only responsibilities proven by repeated implementation;
- source, cache and generated public assets coexist and require clear ownership discipline;
- dynamic remote data can introduce controlled warnings or unrelated refresh changes.

These are reasons for incremental cleanup, not reasons for a complete rewrite.

## 18. Evolution rule

The generator must evolve through observed repetition.

A new abstraction is justified only when:

1. the same responsibility occurs in multiple places;
2. the repeated behavior is stable enough to describe;
3. extraction reduces duplication;
4. the new boundary is easier to understand than the old duplication;
5. the change preserves or improves inspectability.

## 19. Current development phase

```text
Website 3.3
architecture cleanup completed
content integration completed
incremental build and archive consolidation completed
Componentization Phase 2 completed and accepted
maintenance and evidence-driven evolution active
```

The accepted standalone component layer is:

```text
Archive Links
News Journal
Commit Journal
```

No additional standalone component is currently justified.

The next architectural work must arise from new observed repetition, a concrete maintenance need or a feature that exposes a stable responsibility boundary.

## 20. Architectural baseline statement

The Lunar Linux website is a static, Git-centered publishing system.

Markdown and structured data provide content.

Shell and `awk` interpret and compose that content.

Templates provide shared framing.

The `docs/` directory contains public output.

The system should become more componentized only where new real repetition proves that a reusable boundary exists. Componentization Phase 2 established a healthy stopping point for Website 3.3.
