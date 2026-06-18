---
title: About Lunar Linux | Lunar Linux Documentation
description: Lunar Linux documentation: About Lunar Linux.
layout: page
permalink: pages/docs-about-lunar-linux.html
---

# About Lunar Linux

Learn about Lunar Linux, a source-based Linux distribution that builds optimized software tailored to your system

## On This Page

- [What is Lunar Linux?](#what-is-lunar-linux)
- [How is it Licensed?](#how-is-it-licensed)
- [How Does it Work?](#how-does-it-work)
- [What is the Advantage?](#what-is-the-advantage)
- [How Can I Get Started?](#how-can-i-get-started)
- [What Do I Get When I Install the ISO?](#what-do-i-get-when-i-install-the-iso)
- [So What Should I Do Now?](#so-what-should-i-do-now)
- [Philosophy](#philosophy)

## What is Lunar Linux?
Lunar is a source-based Linux distribution developed by a very talented team of programmers from all over the world, working together to extend Linux technology into better-tailored and more optimized software for the end user.

Lunar uses and builds upon the Linux kernel, the software started by Linus Torvalds and supported by thousands of programmers worldwide, and offers a unique package management system which builds each software package, or module, from scratch for the machine in which it is being installed.

**This is what sets Lunar apart.** It makes customization a breeze - you choose the compile options before a module is built, and install a lean and uncluttered system that has exactly what you need. Nothing more, or less.

Once installed, Lunar is remarkably fast, breaking new ground in flexibility and in the options it offers the individual user.

## How is it Licensed?
Lunar Linux and all its code are licensed under the GPLv2.

## How Does it Work?
In a nutshell: Lunar installs a complete bootstrap development system on your machine. You then tell the Lunar package manager what tools you want, and it builds the entire system by downloading current source code and locally compiling an optimized system tailored toward your specific needs.

### Installation Process
Lunar's installer is fast and provides full control over the process of installation, including a wide variety of install and rescue tools. The installer provides the user with an interface to compile a custom kernel during installation.

### Package Management
Installing applications is remarkably simple - type in *lin \[package name\]* and the system will install the application from the moonbase, our module repository. Don't want it after all? Type *lrm \[package name\]* and it is gone.

Lunar has a unique shell-based Application Management System which handles the dependencies when installing software. There is no "dependency hell" - if there are other things the system needs to install a particular application, the AMS will simply find them for you.

### Updating
Updating Lunar is a matter of one single command: *lunar update*. It fetches an updated moonbase, checks if there were any updated modules and builds those. The AMS is network-aware and uses the network to acquire source code. The moonbase and core tools are updated every hour at Lunar-Linux.org.

## What is the Advantage?
The advantage for the end user is clear: a system that is both robust and stable, and easy to install and maintain without sacrificing variety and flexibility.

Lunar has:

- Built-in integrity checking
- Robust self-repairing capability
- The ability for users to develop their own source-packages using the toolset

### Who is it For?
Lunar is for everyone. Though it may be difficult for the beginner to administer, it provides you with all the possible features you could want from a Linux distribution. It is incredibly accessible to anyone who has played around with a UNIX system.

All of this presents a rich potential for a user who seeks:

- **Speed** - Optimized compilation for your specific hardware
- **Strong performance** - Lean, efficient system
- **Smart operation** - A system that "works smart"

## How Can I Get Started?
If you'd like to start using Lunar, you can easily obtain downloads and ISO images from our web site.

You will also need to download our installation manual, which will walk you through everything you need to know about installing Lunar on your machine.

As you begin to put Lunar to work, you will find additional resources in our support section, including:

- Our FAQ
- Man pages
- Mailing list archives

## What Do I Get When I Install the ISO?
The Lunar Linux ISO installs only a basic set of packages needed to build the rest. There is no GNOME or KDE, not even XOrg on your machine after you finish installing the ISO.

### Default Installation
- The only service running is secure shell (ssh)
- Root logins are expressly prohibited
- Once you compile a kernel to get the kernel sources in */usr/src/linux*, you can *lin XOrg7* and start installing your desktop from there

### Available Tools
Although this may sound spartan to you, there are still a ton of things you can do with a finished installation:

- **links** - Text-based web browser to surf to webpages
- **irssi** - IRC chat client
- **Networking tools** - Complete set of networking utilities
- **Hardware utilities** - lspci, dmidecode, discover to figure out what hardware your system has

## So What Should I Do Now?
You should either:

- Go to the download section
- Read some more in the documentation

### Useful Links
- [Lunar Linux Website](http://lunar-linux.org/)
- Installation Guide
- FAQ
- Package Management

## Philosophy
At Lunar, we believe in:

- **Transparency** - You know exactly what's on your system
- **Control** - You choose what gets installed and how
- **Optimization** - Your system is built for your hardware
- **Simplicity** - Powerful tools with clean interfaces
- **Community** - Open source collaboration

*Copyright 2003, Lunar-Linux.org, written by Suzanne Burns*

*"History is irrelevant, only the future matters"*

## Related Articles

general

### About Lunar Linux
Learn about Lunar Linux, a source-based Linux distribution that builds optimized software tailored to your system

