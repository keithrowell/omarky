---
title: Render each Markdown block as its own native component
number: 0001
status: accepted
date: 2026-09-30
deciders: [OmaRead maintainers]
tags:
  - rendering
  - performance
  - typography
supersedes: ADR-0000
summary: >
  The document is a flat list of blocks, and each block type gets its own QML component,
  instead of one rich-text document or a web view. Tables, code and alerts can then be drawn
  the way a designer would draw them, and a long file only builds what is on screen.
links: https://github.com/keithrowell/omaread/blob/main/docs/decisions/0001-flat-blocks-in-a-listview.md
draft: false
---

# Front matter

The YAML block at the top of this file is drawn as a card: the title first, then key and value
rows. Short values such as the status and the date become pills, lists become chips, and long
values wrap.

A document without a title key simply starts with its rows.
