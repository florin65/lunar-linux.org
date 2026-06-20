---
title: Moonbase | Lunar Linux Documentation
description: Lunar Linux documentation: Moonbase.
layout: page
permalink: pages/docs-moonbase.html
---

# Moonbase

Understanding Moonbase, the heart of Lunar Linux

## On This Page

- [Sections](#sections)
- [Modules](#modules)
- [Summary](#summary)
- [Viewing and Browsing](#viewing-and-browsing)
- [Updating the Moonbase](#updating-the-moonbase)
- [Related Topics](#related-topics)

## Sections
The moonbase's first level of structure and organization is a **section**. A section is a name that serves to classify and organize a group of modules into logical partitions.

Each section is simply a subdirectory that resides right below the root of the moonbase or inside another section. Sections can also be nested in other sections.

### Special Sections
There are two sections of special significance:

#### [zbeta](#zbeta)

Contains modules that are:

- Downloaded directly from live source code repositories (\*-cvs or \*-svn modules)
- Unable to be tested extensively by the Lunar team due to hardware availability or other constraints

These modules cannot be guaranteed to work at all times on all hardware.

#### [zlocal](#zlocal)

Where users can:

- Develop their own modules
- Copy and edit existing moonbase modules without risk of them being overwritten next time the moonbase is updated

This is your personal workspace for module development and customization.

## Modules
Modules sit in a section directory. A module consists of a directory with specific files and other directories that are not sections. These subdirectories represent a single module that "belongs" to that section of the moonbase.

A module, to be a bit simplistic, is a set of "instructions" to perform a task - namely, instructions to compile and then install what was compiled onto the user's filesystem.

### Example
If we had a module named FooGame that was located in the "games" section of the moonbase, we would find a directory called FooGame at:

*/var/lib/lunar/moonbase/games/FooGame*

## Summary
To summarize:

- Installable software packages are called **modules**
- The collection of all modules is called the **moonbase**
- The moonbase is simply a directory containing logical **sections** (subdirectories)
- Sections in turn, contain the **module** directories

### Structure Diagram

@@INCLUDE:moonbase-diagram.html@@

## Viewing and Browsing
You can explore the moonbase structure using several methods:

### Command Line
*# List all sections*

*ls /var/lib/lunar/moonbase/*

*# List modules in a specific section*

*ls /var/lib/lunar/moonbase/games/*

*# View all modules in a section*

*lvu section games*

*# Search for a module*

*lvu search keyword*

### Web Interface
Browse the moonbase online at [lunar-linux.org](http://www.lunar-linux.org/) to see available modules and their details.

## Updating the Moonbase
The moonbase should be updated regularly to get the latest module definitions:

*# Update moonbase to latest version*

*lunar update*

*# Just update moonbase without installing updates*

*lunar renew*

This downloads the latest module definitions from the Lunar Linux servers, ensuring you have access to the newest versions of software packages.

## Related Topics
- [Module Basics](docs-writing-modules.html) - Learn how modules are structured
- [Lin Basics](docs-package-management.html) - Using the package installer
- [Module Submission](docs-writing-modules.html) - Contributing your own modules

## Related Articles

development

### Module Submission
How to submit new or updated modules to the official Lunar Linux moonbase

development

### Module Basics
Understanding the structure and scripts that make up a Lunar Linux module

development

### Module Function Reference
Reference guide for functions available in Lunar module scripts

