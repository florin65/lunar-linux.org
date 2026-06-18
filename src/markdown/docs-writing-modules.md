---
title: Writing Modules | Lunar Linux Documentation
description: Lunar Linux documentation: Writing Modules.
layout: page
permalink: pages/docs-writing-modules.html
---

# Writing Modules

Learn how Lunar modules are structured and maintained

## On This Page

- [Before You Start](#before-you-start)
- [Starting the Module](#starting-the-module)
- [Module Format](#module-format)
- [Creating the DETAILS File](#creating-the-details-file)
- [Adding Dependencies](#adding-dependencies)
- [Creating a BUILD Script](#creating-a-build-script)
- [Testing Your Module](#testing-your-module)
- [Common Pitfalls](#common-pitfalls)
- [Best Practices](#best-practices)
- [Advanced Topics](#advanced-topics)
- [Next Steps](#next-steps)
- [Resources](#resources)
- [Getting Help](#getting-help)

## Before You Start
Take some time to think about why you want to make a new module. Also, there might be things to consider that would prevent you from writing a module at all. Here are some quick guidelines:

### Check if the Package Already Exists
Nothing is worse than doing the same work twice.

*\# Search the moonbase for existing modules*

*lvu search packagename*

*\# List all modules*

*lvu section all*

### Check Dependencies
See if the dependencies required for the module also meet these requirements. Sometimes a module might take so much time to write that it's not worth it.

### Consider Alternatives
Check if you're not better off installing it manually or using a binary. Plenty of packages are so easy to install into your home directory that even though a module would be nice, it's often just easier to install it manually.

## Starting the Module
There are two ways to create a new module:

### Quick and Dirty Way
The quick way to create a module is by using *lvu*.

*\# Create a new module*

*lvu new mymodule*

This will:

1.  Prompt you for information using cut and paste
2.  Create the directory in zlocal
3.  Create the DETAILS file

Now verify the module:

*\# Change to the module directory*

*lvu cd mymodule*

*\# Check the DETAILS file*

*cat DETAILS*

At this point you should verify that the DETAILS file looks correct.

### Normal Way
Find a good spot in the moonbase. You should always work in the **zlocal** section. Your system moonbase is located in */var/lib/lunar/moonbase*.

*cd /var/lib/lunar/moonbase/zlocal*

*mkdir mymodule*

*cd mymodule*

Every module is defined as the group of files and directories including a DETAILS file in a directory. So we need a DETAILS file:

* MODULE=mymodule*

* VERSION=1.0*

* SOURCE=\$MODULE-\$VERSION.tar.bz2*

* SOURCE_URL=http://my.site.org/files/*

* SOURCE_VFY=sha256:<sha256 checksum>*

* WEB_SITE=http://my.site.org/*

* ENTERED=20050808*

* UPDATED=20050808*

* SHORT="Makes module writing easy"*

*cat\<\<EOF*

*MyModule is a simple tool to explain module writing in*

*detail. It doesn't actually exist but is used as an example*

*for educational purposes.*

*EOF*

This is a basic DETAILS file with all required components. As you can see it's just plain shell code.

**Important:** All Lunar module files are bash code. This means that you should pay special attention to shell meta characters and proper syntax.

This DETAILS file already can be all you need for writing a module, depending on the way "mymodule" needs to be compiled.

## Module Format
See Module Basics for detailed information about available module scripts and module examples.

## Creating the DETAILS File
The DETAILS file is the heart of every module. It contains essential information about the package.

### Required Fields
*MODULE=mymodule \# The name of the module*

*VERSION=1.0 \# The version number*

*SOURCE=\$MODULE-\$VERSION.tar.bz2 \# Source filename*

*SOURCE_URL=http://... \# Source archive URL*

*SOURCE_VFY=sha256:<sha256 checksum> \# SHA256 checksum for verification*

*WEB_SITE=http://... \# Project website URL URL*

*ENTERED=20050808 \# Date module was created*

*UPDATED=20050808 \# Date module was last updated*

*SHORT="short description" \# One-line description*

### Long Description
After the required fields, include a longer description:

*cat\<\<EOF*

*This is a longer description of what the module does.*

*It can span multiple lines and provides more detail*

*about the package's functionality.*

*EOF*

## Adding Dependencies
If your module requires other modules, create a DEPENDS file:

*\# /var/lib/lunar/moonbase/zlocal/mymodule/DEPENDS*

*\# Required dependencies*

*depends gcc*

*depends make*

*\# Optional dependencies*

*optional_depends "gtk+" \\*

* "--with-gtk" \\*

* "--without-gtk" \\*

* "for GUI support"*

## Creating a BUILD Script
If the default build process doesn't work, create a BUILD script:

*\# /var/lib/lunar/moonbase/zlocal/mymodule/BUILD*

*./configure --prefix=/usr \\*

* --sysconfdir=/etc \\*

* \$OPTS &&*

*make &&*

*prepare_install &&*

*make install*

### Important BUILD Notes
- Use *&&* to chain commands together
- Call *prepare_install* before *make install*
- The *prepare_install* function tells the package manager to start tracking files

## Testing Your Module
Once you've created your module files:

*\# Test downloading the source*

*lget mymodule*

*\# Try building the module*

*lin mymodule*

*\# Check what files were installed*

*lvu install mymodule*

*\# Check for broken dependencies*

*lvu links mymodule*

## Common Pitfalls
### Incorrect SOURCE_VFY
Always generate the correct sha256 checksum:

*sha256sum /var/spool/lunar/mymodule-1.0.tar.bz2*

Then copy that into your DETAILS file.

### Missing Dependencies
Make sure to declare all dependencies. Use these commands to help identify them:

*\# Show what libraries a binary needs*

*ldd /usr/bin/mybinary*

*\# Find what module provides a file*

*lvu where /usr/lib/libsomething.so*

### Improper Use of prepare_install
Only call *prepare_install* immediately before installing files:

*\# WRONG*

*prepare_install &&*

*make &&*

*make install*

*\# CORRECT*

*make &&*

*prepare_install &&*

*make install*

## Best Practices
### Use Shell Variables
Take advantage of predefined variables:

*\$MODULE \# Module name*

*\$VERSION \# Module version*

*\$SOURCE_DIRECTORY \# Where source was unpacked*

*\$BUILD_DIRECTORY \# Usually /usr/src*

*\$OPTS \# Options from CONFIGURE*

### Follow Conventions
- Use lowercase for module names
- Use descriptive SHORT descriptions
- Update the UPDATED field only when compile behavior changes
- Test thoroughly before submitting

### Document Your Changes
If you're modifying an existing module, document why:

*\# In the DETAILS file*

*\# Updated to fix compilation with gcc 11*

*UPDATED=20231102*

## Advanced Topics
### Multiple Sources
If your module needs multiple source files:

*SOURCE=\$MODULE-\$VERSION.tar.gz*

*SOURCE2=\$MODULE-docs-\$VERSION.tar.gz*

*SOURCE_URL=http://example.com/*

*SOURCE2_URL=http://docs.example.com/*

*SOURCE_VFY=sha256:<sha256 checksum>*

*SOURCE2_VFY=sha256:<sha256 checksum>*

Then in your PRE_BUILD:

*unpack \$SOURCE &&*

*cd \$SOURCE_DIRECTORY &&*

*unpack \$SOURCE2*

### Patches
If you need to apply patches, use PRE_BUILD:

*\# PRE_BUILD*

*default_pre_build &&*

*patch_it \$SOURCE_CACHE/\$SOURCE2 1*

Where *\$SOURCE2* is the patch file listed in DETAILS.

### Platform-Specific Builds
For 64-bit specific settings, create:

- *DETAILS.x86_64*
- *BUILD.x86_64*

These will override the default files on 64-bit systems.

## Next Steps
Once you have a working module:

1.  Test it thoroughly
2.  Check for any warnings during compilation
3.  Verify all files are installed correctly
4.  Test removal with *lrm mymodule*
5.  Consider submitting it to the moonbase

See Module Submission for information on contributing your module back to the community.

## Resources
- Module Basics - Detailed script documentation
- Module Functions - Available function reference
- Moonbase - Understanding the repository structure

## Getting Help
If you need help writing modules:

- Join \#lunar on irc.freenode.net
- Ask on the lunar mailing list
- Check existing modules for examples

Remember: The best way to learn is by examining existing modules in the moonbase!

## Related Articles

development

### Module Basics
Understanding the structure and scripts that make up a Lunar Linux module

development

### Module Function Reference
Reference guide for functions available in Lunar module scripts

development

### Module Submission
How to submit new or updated modules to the official Lunar Linux moonbase

