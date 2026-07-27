# Lunar Linux Website

The official static website generator for the Lunar Linux project.

**Current version:** Website 3.3
**State:** Active maintenance and evidence-driven evolution

## Philosophy

The website follows the same principles as Lunar Linux itself:

- simplicity;
- transparency;
- maintainability;
- performance;
- user control.

It uses plain text, standard Unix tools, static output and Git-based history. Automation is introduced only where it provides clear and verifiable value.

## Current architecture

The repository contains both authoritative source material and generated public output.

```text
src/markdown/      main page content
src/news/          editorial news entries
templates/         shared HTML templates
components/        deterministic presentation components
tools/             generator and maintenance scripts
archive/           long-term commit and news memory
cache/             local build state and generated fragments
docs/              GitHub Pages output
site.conf           central configuration
```

The build entry point is:

```sh
./build-site.sh
```

The root command resolves to `tools/build-site.sh`.

## Website 3.3 baseline

Website 3.3 completed a major internal evolution while preserving the static shell-based architecture.

The current generator provides:

- Markdown-driven page and news generation;
- dynamic Moonbase and daily ISO data;
- domain-owned news and commit archives;
- deterministic incremental page rebuilding;
- persistent page and news signatures;
- controlled cleanup of stale generated output;
- tolerant archive recovery with optional strict validation;
- persistent administrative build reports;
- compatibility redirects;
- direct fixture tests for extracted journal components.

## Component layer

Componentization Phase 2 is complete and accepted.

The standalone component layer currently contains:

```text
components/archive-links.sh
components/news-journal.sh
components/commit-journal.sh
```

Their contracts, inventories and phase checkpoint are stored under:

```text
components/docs/
```

Direct component tests are stored under:

```text
components/tests/
```

No additional standalone component is currently justified. Future extraction must be based on newly observed repetition or a concrete maintenance need.

## Building

Normal build:

```sh
./build-site.sh
```

Deterministic local build without dynamic-data or archive refresh:

```sh
UPDATE_DYNAMIC_DATA=no UPDATE_ARCHIVE=no ./build-site.sh
```

Force regeneration of eligible output:

```sh
FORCE_REBUILD=yes ./build-site.sh
```

Strict validation modes are available through `STRICT_BUILD=yes` and `STRICT_ARCHIVE=yes`.

See `USAGE.md` for operational details.

## Documentation

```text
USAGE.md                    build, preview and maintenance workflow
MARKDOWN.md                 supported source format
ARCHIVE.md                  archive layout and policy
CHANGELOG-3.3.md             Website 3.3 release summary
docs/Website-Architecture.md current architecture baseline
components/docs/             component contracts and checkpoints
```

## Development direction

Website 3.3 is at a healthy architectural stopping point.

The next change should not be selected from an old speculative roadmap. It should arise from:

- a real maintenance problem;
- new repeated implementation;
- a stable feature boundary;
- verified community or project needs.

## Project URL

```text
https://florin65.github.io/lunar-linux.org/
```

## Guiding principle

> Less complexity. More satisfaction.

## Lunar Linux

> It's out of this world!
