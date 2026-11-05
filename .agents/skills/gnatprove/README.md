# GNATprove Skill

An agent skill for writing and proving SPARK code with GNATprove.

## What this skill does

Frontier agents already write SPARK and run GNATprove well. This skill gives
them only what they are likely to miss:

- SPARK and GNATprove features newer than their training data, each marked
  with the first release that has it;
- results that look like success but prove nothing (no checks generated,
  uninstantiated generics, cached results, unseen bodies);
- rules against making checks disappear without proving them;
- restrictions that force a redesign when found late;
- how to read the installed release and find its User's Guide.

Everything else is left to the SPARK User's Guide and Reference Manual, which
the skill links for the installed release.

## Guidance for maintainers

- **Keep it shallow.** Add an item only if it changes what a frontier agent
  does at the moment it acts, and it is not something GNATprove's own messages
  or `--explain` codes already tell it. Link the manual rather than restating
  it.
- **Mark versions.** Follow CLAUDE.md § Version-Specific Content; the covered
  range and marker rules live in `references/versions.md`.
- **Do not assume a toolchain location.** Setups differ (Alire, SPARK Pro
  under various prefixes, containers, project scripts). The skill detects
  `alire.toml`, then `PATH`, then asks the user. Do not add hardcoded paths or
  environment assumptions.
- **The description is the trigger.** Agents decide from it whether to load
  the skill, and usage data showed they rarely did when it spoke only of
  running GNATprove. Keep it aimed at writing SPARK as well as proving it.

## Installation

Install into your agent platform per its skill installation instructions.
Once installed, invoke with `/gnatprove` (or your platform's equivalent).
