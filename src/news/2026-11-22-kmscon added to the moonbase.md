Date: 2026-11-22 09:15
Category: Development
Title: kmscon added to the moonbase

KMSCON is a DRM/KMS userspace terminal emulator.

This local Lunar module applies Florin's four ordered clipboard patches to
upstream KMSCON 10.1.2, builds the native X11/Wayland user-session peers and
provides optional, manual-only dinit service templates.

No Xvfb, systemd, libseat, D-Bus or accelerated OpenGL 15 backend is required
by the selected DRM2D profile.
