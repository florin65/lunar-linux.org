---
title: Installation Guide | Lunar Linux Documentation
description: Lunar Linux documentation: Installation Guide.
layout: page
permalink: pages/docs-installation-guide.html
---

# Installation Guide

Step-by-step guide to installing Lunar Linux

## On This Page

- [Before You Begin](#before-you-begin)
- [Installation Steps](#installation-steps)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Before You Begin
Ensure you have:

- Met the system requirements
- Backed up any important data
- Created a bootable Lunar Linux USB drive

## Installation Steps
### 1. Boot from Installation Media
1.  Insert the Lunar Linux installation media

2.  Restart your computer

3.  Enter BIOS/UEFI settings (usually F2, F12, or Del key)

4.  Set boot priority to USB/CD drive

5.  Save and exit

### 2. Start the Installer
Once booted, you'll see the Lunar Linux welcome screen.

Start the installation process:

*lunar-install*

### 3. Partition Your Disk
The installer will guide you through disk partitioning.

**Recommended partition scheme:**

*/dev/sda1 512M EFI System Partition (if UEFI)*
*/dev/sda2 4G Swap*
*/dev/sda3 Rest Root filesystem (/)*

### 4. Configure Network
Configure your network connection for package downloads during installation.

### 5. Install Base System
The installer will:

- Format partitions
- Install base packages
- Configure bootloader

This may take 30-60 minutes depending on your system and internet speed.

### 6. Set Root Password
When prompted, set a secure root password.

### 7. Create User Account
Create your primary user account:

*useradd -m -G wheel username*
*passwd username*

### 8. Reboot
Once installation completes:

*reboot*

Remove the installation media when prompted.

## Post-Installation
After rebooting into your new system:

1. Log in with your user account
2. Update the system: *lunar update* (or *lunar renew*)
3. Install additional software as needed

## Troubleshooting
### Boot Issues
If system won't boot:

- Verify BIOS/UEFI boot order
- Check bootloader configuration
- Ensure partitions were formatted correctly

### Network Issues
If network isn't working:

- Check network cable connection
- Verify network configuration
- Test with: *ping -c 3 lunar-linux.org*

## Next Steps
- Learn about package management
- Explore system administration

## Related Articles

general

### Frequently Asked Questions
Common questions and answers about Lunar Linux, installation, optimization, and package management

installation

### Advanced Installation Methods
Alternative and advanced installation techniques for Lunar Linux

installation

### Kernel Command Line Parameters
Configuring device node handling via bootloader kernel parameters

