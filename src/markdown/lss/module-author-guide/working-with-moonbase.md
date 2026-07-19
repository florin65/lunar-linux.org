---
title: "Working with Moonbase"
description: "Inspecting, updating, comparing, and maintaining the active Moonbase safely."
---

# Working with Moonbase

Moonbase is the active collection of module definitions used by LSS.

It is not the installed system.

```text
Moonbase
→ module intent and build policy

/var/state/lunar/packages
→ installed package and policy state

/var/log/lunar/install
→ final ownership
```

## Active Moonbase

A common active location is:

```text
/var/lib/lunar/moonbase
```

Inspect it directly:

```bash
git -C /var/lib/lunar/moonbase status --short
git -C /var/lib/lunar/moonbase branch --show-current
git -C /var/lib/lunar/moonbase rev-parse HEAD
```

The active local Moonbase explains what the current system will execute.

An upstream repository explains upstream intent, but it may differ from the active copy.

## Locate a module

```bash
MODULE=name
SECTION=$(lvu where "$MODULE")
MODULE_DIR="/var/lib/lunar/moonbase/$SECTION/$MODULE"

printf '%s
' "$MODULE_DIR"
```

Inspect all module files:

```bash
find "$MODULE_DIR" -maxdepth 2 -type f -print | sort
```

## Record the current revision

Before a significant update:

```bash
git -C /var/lib/lunar/moonbase rev-parse HEAD \
  > /root/moonbase-revision.before

git -C /var/lib/lunar/moonbase branch --show-current \
  > /root/moonbase-branch.before

git -C /var/lib/lunar/moonbase status --short \
  > /root/moonbase-status.before
```

Preserve local changes:

```bash
git -C /var/lib/lunar/moonbase diff \
  > /root/moonbase-local-changes.patch
```

Do not update over unknown local modifications.

## Compare revisions

Compare one module:

```bash
git -C /var/lib/lunar/moonbase diff   OLD..NEW -- section/module
```

List changed files:

```bash
git -C /var/lib/lunar/moonbase diff   --name-only OLD..NEW
```

Inspect history:

```bash
git -C /var/lib/lunar/moonbase log --   section/module
```

A module may change without changing upstream version.

Possible changes include:

- patch additions;
- dependency corrections;
- compiler selection;
- installation paths;
- hooks;
- optional-feature defaults;
- source verification.

## Updating Moonbase does not update installed software

```text
Moonbase update
→ definitions change

installed system
→ unchanged until install, rebuild, or removal
```

After updating Moonbase, review affected modules before rebuilding them.

See [Updating Lunar Linux Safely](../user-guide/updating-safely.html).

## Local changes and branches

Safe ways to preserve local work include:

- commit local changes;
- use a dedicated branch;
- export a patch;
- move private modules into a clearly identified local section;
- pin a known revision.

Avoid an unmanaged mixture of local edits and upstream updates.

## Local modules

A dedicated local section makes provenance clearer.

Conceptually:

```text
local/utils
local/libs
local/services
```

Benefits include:

- fewer merge conflicts;
- easier backup;
- clearer review;
- safer upstream updates.

Use the conventions supported by the active Moonbase.

## Search Moonbase

Search for dependencies:

```bash
grep -R -n -F 'dependency-name'   /var/lib/lunar/moonbase
```

Find hooks:

```bash
find /var/lib/lunar/moonbase -type f \
  \( -name PRE_BUILD -o -name POST_BUILD \
     -o -name POST_INSTALL -o -name PRE_REMOVE \
     -o -name POST_REMOVE \) \
  -print
```

Find patches:

```bash
find /var/lib/lunar/moonbase -type f \
  \( -name '*.patch' -o -name '*.diff' \) \
  -print
```

Find plugin-related modules:

```bash
grep -R -n -E 'plugin\.d|\.plugin'   /var/lib/lunar/moonbase
```

## Reproducibility record

For an important build, preserve:

```bash
OUT=/root/lss-build-record
mkdir -p "$OUT"

git -C /var/lib/lunar/moonbase rev-parse HEAD \
  > "$OUT/moonbase-revision"

git -C /var/lib/lunar/moonbase status --short   > "$OUT/moonbase-status"

git -C /var/lib/lunar/moonbase diff   > "$OUT/moonbase-diff"

cp -a "$MODULE_DIR" "$OUT/module-definition"
```

Also preserve configuration, toolchain information, package state, and dependency state when exact reproduction matters.

## Safe Moonbase workflow

```text
inspect active revision
→ preserve local changes
→ update definitions
→ review diffs
→ classify affected modules
→ rebuild selectively
→ verify state and runtime
```

Continue with [Moonbase Module Anatomy](moonbase-module-anatomy.html) and [Building and Testing a Local Module](building-and-testing.html).
