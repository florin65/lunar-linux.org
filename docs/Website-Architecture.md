# Lunar Linux Website Architecture

**Version:** 0.1  
**Date:** 2026-07-12  
**Status:** Current architecture baseline  
**Project:** Lunar Linux Website 3.2 — The Next Generation

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
            ├── page rendering
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
9. rendering Markdown pages;
10. composing the final HTML document;
11. generating compatibility redirects;
12. cleaning temporary files.

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

Website 3.2 uses domain ownership instead of a central Archive domain.

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
- dynamic project data;
- generated news and archives;
- compatibility redirects;
- GitHub Pages deployment;
- progressive improvement without framework lock-in.

## 17. Current architectural limits

The current system also has real limits:

- `build-site.sh` owns too many responsibilities;
- `render-page.sh` contains several page-specific rendering paths;
- reusable page fragments are not yet formalized as components;
- some behavior is selected by page name;
- shared presentation elements are only partially componentized;
- project documentation has lagged behind implementation;
- generated and source assets coexist in ways that require discipline.

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
Website 3.2
Alpha 1 — architecture cleanup completed
Alpha 2 Sprint A — content integration completed
Alpha 2 Sprint B — component foundation active
```

The next architectural work is:

```text
Component Specification 0.1
        ↓
Archive Links component
        ↓
Footer component
        ↓
Navigation component
        ↓
incremental generator cleanup
```

## 20. Architectural baseline statement

The Lunar Linux website is a static, Git-centered publishing system.

Markdown and structured data provide content.

Shell and `awk` interpret and compose that content.

Templates provide shared framing.

The `docs/` directory contains public output.

The system should become more componentized only where real repetition proves that a reusable boundary exists.
