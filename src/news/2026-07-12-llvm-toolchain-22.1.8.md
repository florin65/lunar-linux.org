Date: 2026-07-12 18:50
Category: Development
Title: LLVM toolchain updated to 22.1.8

The Lunar Linux LLVM toolchain has been updated to version 22.1.8.

The LLVM project is now maintained through separate Lunar modules for `llvm`, `clang`, `lld`, `compiler-rt` and `openmp`.

The update also aligns the build process around the Clang toolchain for LLVM-family components, avoiding incompatibilities caused by passing Clang-specific compiler options to GCC.

This work keeps the toolchain structure closer to upstream while preserving the simple and inspectable Lunar module model.
