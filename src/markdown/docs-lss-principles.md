---
title: The Principles of LSS | Lunar Linux
description: The engineering principles behind the Lunar Scripts System.
layout: page
permalink: pages/docs-lss-principles.html
---

# The Principles of LSS

> **Less complexity, more Linux.**

## Introduction

The Lunar Scripts System is the collection of tools that builds, installs, updates and maintains a Lunar Linux system.

Its design reflects a simple goal: provide powerful system management without hiding Linux behind unnecessary layers.

These principles describe what LSS should preserve as it evolves.

## Linux First

LSS exists to manage Linux, not to replace or conceal it.

Standard Linux concepts, tools, files and administration skills should remain visible and useful.

Knowledge gained while using Lunar Linux should transfer naturally to other Linux systems.

## Source Preserves Understanding

Source code provides more than software.

It preserves the ability to inspect, understand, adapt, rebuild and verify the system.

LSS therefore treats source-based operation as both a technical model and a means of keeping knowledge accessible.

## Keep Software Close to Upstream

Lunar Linux should keep software close to upstream and the authors' intentions.

Patches and downstream changes should be limited to what is necessary for correct integration, compatibility or security.

Fewer unnecessary differences make software easier to understand and maintain.

## Simplicity is Engineering

Simplicity is not the absence of capability.

It is the result of separating responsibilities, removing unnecessary layers and keeping behavior understandable.

A simple system may require careful engineering, but it reduces the long-term cost of administration and maintenance.

## Understanding Before Automation

Automation should follow understanding.

Before a process is automated, its inputs, decisions, exceptions and consequences should be understood.

Automation must remove repetitive work without removing visibility or control.

## Engineering Before Cleverness

Readable and dependable solutions are preferred over clever ones.

Code should make its purpose and behavior clear to future maintainers.

A solution that is easy to inspect, test and repair is more valuable than one that is merely compact or ingenious.

## Knowledge is Part of the System

Documentation, history, design decisions and engineering experience are part of LSS.

Code explains what the system does.

Preserved knowledge explains why it does it that way and how it can evolve safely.

## Evolve, Don't Reinvent

LSS should evolve from its proven foundation.

Existing behavior should be understood before it is replaced.

New implementations are justified when they provide clear value while preserving compatibility, knowledge and the strengths of the current system.

## Community is the Long-Term Architecture

Software survives through people who understand and maintain it.

Readable tools, accessible documentation and preserved history make participation possible.

The long-term strength of LSS depends not only on its code, but also on the community knowledge surrounding it.

## Looking Forward

LSS can adopt new languages, interfaces and implementation techniques without abandoning its principles.

Its future should preserve transparency, control, source-based operation and closeness to Linux.

> Software can always be rewritten. Engineering wisdom cannot.
