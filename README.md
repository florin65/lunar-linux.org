# Lunar Linux Website

Modern static website for the Lunar Linux project.

## Philosophy

The website follows the same principles as Lunar Linux itself:

* Simplicity
* Transparency
* Maintainability
* Performance
* User control

No unnecessary complexity.
No heavyweight infrastructure.
Just static content, Git repositories and automation where it makes sense.

---

## Project Goals

* Modern and responsive design
* Lightweight and fast loading
* Static-site architecture
* Git-based workflow
* Easy maintenance
* Community-friendly contribution model
* Preserve the traditional Lunar Linux identity

---

## Current Status

### Release Status

**Version:** 2.5

**State:** Stable

The public release has been completed and published for the community evaluation.

---

## Completed

### Foundation

* [✓] Repository created
* [✓] Project structure defined
* [✓] Visual assets imported
* [✓] Site navigation implemented

### Content

* [✓] Homepage completed
* [✓] About section completed
* [✓] Download section completed
* [✓] Documentation section completed
* [✓] Community section completed
* [✓] Development section completed

### Design

* [✓] Responsive layout
* [✓] Visual modernization
* [✓] Lunar Linux branding refresh
* [✓] GitHub Pages deployment

### Community

* [✓] Public evaluation announced
* [✓] Initial community feedback received

### News System

* [✓] Create News page
* [✓] Transform the website to a dynamic one, based on markdown pages
* [✓] Create individual news entries
* [✓] Generate News automatically from Git activity

### Automation

* [✓] Markdown-driven content workflow
* [✓] Static page generation
* [✓] Automated site updates from repository activity
* [✓] Add "Latest Activity" panel on Home
* [✓] Add a personal Lunar related projects page for the community members

---

## Roadmap

### Activity Tracking

* [✓] Add a Lunar Linux project history page
* [✓] More automation added to the site 
* [✓] The great plan can be summarizen in a simple way like this: 

* [ ] Add a page to centralize the community related projects (a Lunar Users Repository)

                 Archive
                     ▲
                     │
                     │
     Docs ◄──────────┼──────────► News
       ▲             │              ▲
       │             │              │
       │             │              │
Development ◄──── Website ────► Community
       │                            ▲
       │                            │
       ▼                            │
      LUR ──────────────────────────┘

---

## Long-Term Vision

The website should reflect the real-time heartbeat of the Lunar Linux project.
Repositories already contain the project's history:

* commits
* releases
* documentation updates
* Moonbase activity

The website should expose this information automatically rather than requiring manual duplication.

---

## Architecture

``````

                Home
                  │
          ┌───────┴────────┐
          │                │
       About            Download
          │
          │
    ┌─────┴─────┐
    │           │
  News        LUR
    │           │
    ▼           ▼
 Latest      Projects
    │           │
    └─────┬─────┘
          ▼
       Archive
          │
 ┌────────┼───────────┐
 │        │           │
News   Commits    Documentation
 │        │           │
 ▼        ▼           ▼
History Timeline   Memory

---

## Guiding Principle

> Less complexity. More satisfaction.

                build-site.sh
                    │
               (balansier)
                    │
    ┌───────────────┼──────────────┐
    │               │              │
    ▼               ▼              ▼
moonbase       news.json       docs.md
commits            │               │
    │              │               │
    ▼              ▼               ▼
archive-      archive-         generator
commits       news                │
    │              │              │
    └──────┬───────┴───────┬──────┘
           ▼               ▼
        archive/         docs/
           │               │
           └──────┬────────┘
                  ▼
           GitHub Pages

---

## Project URLs

Website project page:  https://florin65.github.io/lunar-linux.org/

---

## Lunar Linux

"It's out of this world!"
