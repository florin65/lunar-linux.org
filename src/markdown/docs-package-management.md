---
title: Package Management | Lunar Linux Documentation
description: Lunar Linux documentation: Package Management.
layout: page
permalink: pages/docs-package-management.html
---

# Package Management

Managing packages with Lunar's source-based package management system

## On This Page

- [What Makes Lunar Different](#what-makes-lunar-different)
- [Package Management Tools](#package-management-tools)
- [Core Components](#core-components)
- [Comparison to Other Systems](#comparison-to-other-systems)
- [Getting Started](#getting-started)

## What Makes Lunar Different
Lunar Linux's package management system is distinctive because all applications are compiled directly from source code, rather than installed from pre-compiled binaries. This approach offers several advantages:

- **Optimization:** Software is compiled specifically for your hardware
- **Customization:** Choose exactly which features to include or exclude
- **Transparency:** See exactly what's being installed
- **Flexibility:** Easy to modify or patch packages
- **Currency:** Access to latest upstream sources

## Package Management Tools
Lunar provides two mutually exclusive package management implementations:

### lunar (Stable)
The stable, production-ready package management system. This is what most users should run.

*lin package-name # Install a package*

*lunar update # Update all installed packages*

*lunar renew package-name # Rebuild a package*

### theedge (Development)
The development branch containing experimental features and improvements. Use this only if you want to help test new functionality or need bleeding-edge features.

*lin theedge # Switch to development branch*

**Important:** *lunar* and *theedge* are mutually exclusive. Installing one removes the other.

## Core Components
### lin - Package Installation Tool
The primary command for installing packages. See lin Basics for detailed usage.

### Moonbase - Package Repository
The moonbase is Lunar's package repository, containing module definitions for thousands of software packages. See Moonbase Overview for more information.

### Modules
In Lunar, a "module" is a package definition containing:

- Source download locations
- Build instructions
- Dependency information
- Configuration options

## Comparison to Other Systems

If you're familiar with other package managers, this comparison gives a rough orientation:

- **Debian / Ubuntu** — `apt` / `dpkg` — binary packages
- **Red Hat / Fedora** — `yum` / `rpm` / `dnf` — binary packages
- **Gentoo** — `emerge` / `portage` — source-based packages
- **Arch Linux** — `pacman` — binary packages
- **Lunar Linux** — `lin` / `lunar` — source-based modules

Lunar is most similar to Gentoo's Portage in being source-based, but it follows a smaller, simpler and more direct philosophy.

## Getting Started

For new users, start with these guides:

- [Installation Guide](docs-installation-guide.html)
- [About Lunar Linux](docs-about-lunar-linux.html)

## See Also

- [Moonbase](docs-moonbase.html)
- [Writing Modules](docs-writing-modules.html)
- [Installation Guide](docs-installation-guide.html)
