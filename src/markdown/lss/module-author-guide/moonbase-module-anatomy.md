---
title: "Moonbase Module Anatomy"
description: "The purpose of common files in a Moonbase module."
---

# Moonbase Module Anatomy

A Moonbase module is executable package policy.

It describes:

```text
source identity
→ dependency choices
→ build procedure
→ installation
→ integration
→ removal behavior
```

Common files include:

```text
DETAILS
BUILD
DEPENDS
CONFIGURE
OPTIONS
PRE_BUILD
POST_BUILD
POST_INSTALL
PRE_REMOVE
POST_REMOVE
CONFLICTS
```

A module may also include patches, helper scripts, service files, configuration templates, and plugin files.

## DETAILS

`DETAILS` defines the identity and source of the module.

Typical fields describe:

- module name;
- upstream version;
- source archive;
- source URL;
- source verification;
- project website;
- entry and update dates;
- short and long descriptions.

A simplified example:

```bash
MODULE=example
VERSION=1.0
SOURCE=$MODULE-$VERSION.tar.xz
SOURCE_URL=https://example.org/releases/
SOURCE_VFY=sha256:CHECKSUM
WEB_SITE=https://example.org/
ENTERED=20260718
UPDATED=20260718
SHORT="Example software"

cat << EOF
A longer description of the software.
EOF
```

Use the exact conventions accepted by the active Moonbase.

Source verification is part of the module contract. A version string and URL are not sufficient without a trusted checksum or signature mechanism.

Upstream version is also not complete build identity.

```text
same upstream version
≠ same resulting package
```

The result may differ because of:

- Moonbase revision;
- patches;
- optional dependencies;
- selected providers;
- compiler family and version;
- compiler and linker flags;
- local configuration;
- generated files.

## BUILD

`BUILD` defines the build and installation procedure.

A conventional example:

```bash
./configure --prefix=/usr &&
make &&
prepare_install &&
make install
```

A simple Makefile project may use:

```bash
make &&
prepare_install &&
make install PREFIX=/usr
```

The shell `&&` chain matters. Each command runs only if the previous command succeeds.

Avoid sequences that continue after a failed configure, build, or installation step.

Review:

- command ordering;
- configure and build flags;
- compiler selection;
- destination paths;
- patches and generated files;
- cleanup behavior;
- whether installation begins only after `prepare_install`.

## Standard helpers

Moonbase modules may use helpers such as:

```bash
default_build
default_make
```

These reduce repeated boilerplate for common build systems.

Inspect the implementation in the active LSS version before assuming that a helper matches every upstream project.

Modules may also use helpers such as `sedit` for controlled source or configuration edits.

Every non-obvious edit should have a clear compatibility or packaging reason.

## DEPENDS

`DEPENDS` defines required and optional relationships.

A required dependency describes software needed for the selected module form.

An optional dependency usually maps a feature choice to:

- dependency state;
- a positive build flag;
- a negative build flag;
- a short explanation.

The declaration should not depend on accidental software already installed on the maintainer's machine.

Test in a minimal environment to discover hidden dependencies.

## CONFIGURE and OPTIONS

`CONFIGURE` and `OPTIONS` expose module-specific choices.

Good options are:

- meaningful to the administrator;
- stable across module revisions;
- reproducible;
- connected to explicit build behavior.

Prefer explicit enable and disable flags over uncontrolled upstream auto-detection.

Configuration choices become part of the practical package identity and may affect cache suitability.

## Patches and auxiliary files

A module may include:

- source patches;
- service definitions;
- default configuration;
- desktop files;
- helper scripts;
- plugin files.

A patch should record:

```text
purpose
affected version
source or author
upstream status
condition for removal
```

A patch file has no effect unless module logic actually applies it.

Search:

```bash
grep -R -n -E 'patch|sedit' "$MODULE_DIR"
```

## PRE_BUILD

`PRE_BUILD` runs before the main build procedure.

Typical uses:

- applying patches;
- regenerating build-system files;
- preparing architecture-specific source;
- setting compiler-family requirements.

It should modify the build environment, not install unmanaged live-system payload.

## POST_BUILD

`POST_BUILD` runs after the main build procedure.

It may:

- remove unwanted installed files;
- normalize the installed payload;
- adjust permissions;
- perform packaging cleanup.

A file can therefore appear in raw installwatch history and still be absent from the final manifest.

## POST_INSTALL

`POST_INSTALL` runs after the main installation transaction.

It may update:

- caches;
- indexes;
- service integration;
- boot metadata;
- plugin state.

Because it occurs after normal installation boundaries, review its side effects carefully.

## PRE_REMOVE and POST_REMOVE

Removal hooks may stop services, clean generated state, rebuild indexes, or perform other system integration.

Inspect them before removing a complex module:

```bash
for hook in PRE_REMOVE POST_REMOVE; do
  test -f "$MODULE_DIR/$hook" || continue
  sed -n '1,240p' "$MODULE_DIR/$hook"
done
```

## CONFLICTS

`CONFLICTS` describes modules or providers that should not coexist.

A conflict can represent:

- overlapping implementations;
- incompatible files;
- mutually exclusive providers;
- known operational breakage.

Do not replace a conflict declaration with ad hoc file deletion.

## Modules that install plugins

A module may install LSS plugin files.

Search:

```bash
grep -R -n -E 'plugin\.d|\.plugin' "$MODULE_DIR"
```

Such modules require extra care during update and removal because plugin registration order and active processes may matter.

See [Plugins and Extensibility](../plugin-guide/plugins-and-extensibility.html).

## Declared behavior versus final ownership

Moonbase defines intended behavior.

The install manifest records the final paths attributed to the installed module.

```text
Moonbase
→ declared package policy

raw installwatch
→ filesystem events

install manifest
→ final ownership
```

A path touched during the build may be excluded, protected, removed later, or created outside normal ownership tracking.

For the ownership model, see [Logs and Manifests](../debugging-guide/logs-and-manifests.html).

## Review checklist

Before accepting a module, ask:

```text
Is the source verified?
Are dependencies complete?
Are optional features explicit?
Does prepare_install precede live installation?
Are patches documented?
Are hooks necessary and bounded?
Is final ownership clean?
Does removal behave safely?
```

Continue with [Working with Moonbase](working-with-moonbase.html) and [Lifecycle and prepare_install](lifecycle-and-prepare-install.html).
