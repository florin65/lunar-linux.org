---
title: "Updating the System Safely"
description: "A staged method for updating modules, libraries, toolchains, and services."
---

# Updating the System Safely

An update can change:

- version;
- dependencies;
- ABI;
- compiler output;
- installed paths;
- configuration defaults;
- provider selection;
- service behavior.

Use staged updates rather than one undifferentiated system change.

## Before updating Moonbase

```bash
git -C /var/lib/lunar/moonbase status --short
git -C /var/lib/lunar/moonbase rev-parse HEAD \
  > /root/moonbase-revision.before

git -C /var/lib/lunar/moonbase diff \
  > /root/moonbase-local-changes.patch
```

Preserve package and dependency state:

```bash
cp -a /var/state/lunar/packages   /root/packages.before-update

cp -a /var/state/lunar/depends   /root/depends.before-update
```

Check available space:

```bash
df -h
du -sh /var/cache/lunar
du -sh /var/log/lunar
```

A source build may require space for the archive, build tree, object files, installed payload, logs, cache, and old version during replacement.

## Verify source availability

Before a critical update, confirm that required sources remain available and match their expected verification data.

Potential failures include:

- removed upstream archive;
- renamed tag;
- unavailable mirror;
- changed checksum;
- network failure.

Preserve source archives for critical modules when practical.

## Review changed modules

Compare the old and new Moonbase revisions:

```bash
git -C /var/lib/lunar/moonbase diff   OLD..NEW -- section/module
```

Look for:

- version and source changes;
- checksum changes;
- new required dependencies;
- optional-feature changes;
- compiler selection;
- install path changes;
- new hooks;
- removal behavior.

The same upstream version can still have different packaging behavior.

For deeper Moonbase maintenance, see [Working with Moonbase](../module-author-guide/working-with-moonbase.html).

## Update order

```text
dependencies
→ shared libraries
→ direct consumers
→ applications and services
```

A shared-library update may require rebuilding reverse dependents even when their own versions do not change.

Check:

```bash
lvu depends library
lvu leert library
```

## ABI and SONAME transitions

Warning signs include:

- changed SONAME;
- changed major library version;
- removed symbols;
- C++ runtime changes;
- compiler runtime changes;
- language runtime transitions.

Inspect a library:

```bash
readelf -d /usr/lib/libexample.so | grep SONAME
```

After updating, check important consumers:

```bash
ldd /usr/bin/consumer | grep 'not found'
```

Rebuild direct consumers first, then higher-level dependents as needed.

## Toolchain updates

Record:

```bash
gcc --version
clang --version
ld --version
make --version

env | grep -E   '^(CC|CXX|CFLAGS|CXXFLAGS|LDFLAGS|MAKEFLAGS)='
```

Validate the new toolchain on a small known module before rebuilding core components.

Compiler-family consistency matters. A module expecting Clang-specific flags should not silently build with GCC, and vice versa.

## Cache isolation for a fresh build

A trusted cache can help recovery, but it can also hide the normal compile path.

For a controlled fresh build:

```text
preserve old cache
→ move it outside /var/cache/lunar
→ rebuild
→ inspect manifest and runtime
→ preserve the new cache
```

Use this when toolchain, provider, options, patches, or Moonbase recipe changed.

See [Caches and Rollback](../administrator-guide/caches-and-rollback.html).

## Update waves

A practical order:

```text
wave 1
→ small isolated utilities

wave 2
→ common libraries

wave 3
→ applications

wave 4
→ services

wave 5
→ core and toolchain
```

Capture `/var/state/lunar/packages` and `/var/state/lunar/depends` after each major wave.

## Kernel and boot updates

Before updating a kernel, initramfs, bootloader, or firmware:

- retain a known-good kernel;
- retain a working boot entry;
- preserve boot configuration;
- verify available filesystem space;
- verify recovery media or another boot path;
- inspect generated initramfs and boot files before rebooting.

Do not remove the previous working kernel immediately.

## LSS self-update

Updating `lunar` or core LSS functions affects every later package operation.

Before a major self-update, preserve:

```bash
cp -a /var/lib/lunar/functions   /root/lunar-functions.before

cp -a /etc/lunar   /root/lunar-config.before
```

Use a container, chroot, or other recoverable environment for significant LSS changes.

## Service updates

After updating a service:

```text
verify binary
→ compare configuration
→ restart or reload
→ inspect logs
→ test client behavior
```

Installation success is not service validation.

## Detect partial installation

After a failure, inspect:

```bash
grep '^module:' /var/state/lunar/packages
ls -l /var/log/lunar/install/module-*
ls -l /var/log/lunar/md5sum/module-*
command -v program
```

Possible states include:

```text
old record + old payload
new record + new payload
no record + partial payload
record present + missing manifest
```

Do not continue updating other modules until the failed transition is understood.

## Failure response

```text
stop expansion
→ preserve evidence
→ identify failed lifecycle phase
→ inspect package and ownership state
→ restore from trusted cache or rebuild
→ verify before continuing
```

Do not continue a large update after an unexplained core failure.

## Final verification

```bash
lvu installed module
grep '^module:' /var/state/lunar/packages
cat /var/log/lunar/install/module-version
ldd /usr/bin/program | grep 'not found'
```

Test the actual feature or service.
