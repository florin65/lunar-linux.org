# Lunar Linux Website Usage

This document describes how to configure, build, preview and maintain the Lunar Linux website.
The website intentionally follows the same principles as Lunar Linux itself:

- plain text content
- simple Unix tools
- static output
- Git-based workflow
- minimal moving parts

The generated website is completely static.

---

## Requirements

Current build requirements:

- POSIX shell
- awk
- sed
- grep
- sort
- git

The website generator intentionally uses traditional Unix tools only. No additional language runtime is required.

---

## Project layout

```text
src/markdown/      page content
src/news/          community and project news entries
templates/         shared HTML fragments
tools/             build and generator scripts
cache/             temporary build data
docs/              generated website for GitHub Pages
docs/data/         generated JSON data
```

---

## Configuration

The central configuration file is:

```text
site.conf
```

Important settings include:

```sh
PUBLIC_DIR="docs"
DATA_DIR="docs/data"

MOONBASE_DIR="../moonbase"
MOONBASE_LOG_DIR="cache/moonbase-logs"
MOONBASE_NEWS_JSON="docs/data/moonbase-news.json"

COMMUNITY_NEWS_HTML="cache/community-news.html"
NEWS_ARTICLES_DIR="docs/news"
```

---

## Building the site

Run:

```sh
./tools/build-site.sh
```

This updates dynamic data and regenerates the static site in `docs/`.
The build currently performs:

```text
Moonbase statistics
Daily ISO information
Moonbase commit journal
Community/project news
Markdown page rendering
Static HTML generation
```

---

## Previewing locally

Run any small static web server. For example:

```sh
busybox httpd -f -p 8001 -h docs
```

or, if Python is already available on your system:

```sh
python3 -m http.server --directory docs 8001
```

Then open:

```text
http://localhost:8001/
```

If CSS changes do not appear immediately, force-refresh the browser or clear the cache.

---

## Writing page content

Static page content lives in:

```text
src/markdown/
```

Edit these files when changing text shown on the site.
The templates contain layout only. Editorial text should live in Markdown sources.

---

## Writing community/project news

Community and project news entries live in:

```text
src/news/
```

Each news entry is a plain text Markdown file.
Recommended filename format:

```text
YYYY-MM-DD-short-title.md
```

Example:

```text
src/news/2026-06-06-website-2.0-released.md
```

### Required format

Each file must start with three required metadata lines:

```text
Date: 2026-06-06 19:30
Category: Project
Title: Website 2.0 released

The news body starts after the first empty line.
Additional paragraphs may follow.
```

Required fields:

- `Date:`
- `Category:`
- `Title:`

The body starts after the first empty line.

### Date format

Accepted date formats:

```text
YYYY-MM-DD
YYYY-MM-DD HH:MM
```

Examples:

```text
Date: 2026-06-06
Date: 2026-06-06 19:30
```

### Validation

Invalid news files are rejected during the build.
A file is rejected if:

- `Date:` is missing
- `Category:` is missing
- `Title:` is missing
- the date format is invalid
- the body is empty

Rejected files produce warnings but do not stop the website build.

### Generated output

Valid entries are used to generate:

```text
docs/news.html
docs/news/<entry>.html
```

The main News page receives a compact table of community/project news entries.
Each entry also gets its own static HTML page.

---

## Moonbase commits journal

The Moonbase commits journal is generated from local Moonbase Git repositories.
The list of repositories is configured with:

```sh
MOONBASE_REPOS="core efl kde other xfce xorg gnome3 gnome"
```

The default time window is the last 24 hours:

```sh
MOONBASE_LOG_DAYS="1"
```

Generated data:

```text
cache/moonbase-logs/*.log
docs/data/moonbase-news.json
```

The News page displays this information as a compact commit table.

---

## Publishing with GitHub Pages

The project uses `docs/` as the GitHub Pages output directory.

GitHub Pages settings:

```text
Deploy from branch
Branch: main
Folder: /docs
```

---

## Guiding principle

```text
Content     -> src/markdown/ and src/news/
Layout      -> templates/
Automation  -> tools/
Output      -> docs/
```

Keep text in content files.
Keep structure in templates.
Keep logic in scripts.
