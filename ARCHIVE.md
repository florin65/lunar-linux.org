# Lunar Website Archive

The archive keeps a long-term, file-based memory of the Lunar Linux website.
It is deliberately simple: shell scripts, JSON, Markdown and `.xz` files.

## Layout

```text
archive/
├── commits/YYYY/MM/YYYY-MM-DD.json[.xz]
└── news/YYYY/MM/YYYY-MM-DD-<sha12>.md[.xz]
```
## Commands

```sh
tools/archive.sh commits
tools/archive.sh news
tools/archive.sh all
tools/archive.sh close-day
tools/archive.sh list commits 2026 06
tools/archive.sh search moonbeam
```

## Policy

Current-day files remain plain text because they may still receive new entries.
Older files are compressed with `xz` by `tools/archive.sh close-day`.

Commits are deduplicated by commit hash.
News entries are deduplicated by SHA256 of the Markdown file content.
