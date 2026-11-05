# Agent skills

This directory holds the project skills for coding agents. Each skill is a
`<name>/SKILL.md` file in the [Agent Skills](https://agentskills.io) format.

Skills are symbolically linked from `.agents/skills` to `.claude/skills` for
compatability with Claude.

| Skill           | Use it to                                               | Source         |
| --------------- | ------------------------------------------------------- | -------------- |
| `writing-style` | Write docs, Ada comments, and commit messages           | This repo      |
| `gnatprove`     | Write and prove SPARK code, and run SPARK flow analysis | AdaCore/skills |
| `alire`         | Change crates, dependencies, and toolchains             | AdaCore/skills |

## AdaCore skills

`gnatprove/` and `alire/` are unchanged copies from
[AdaCore/skills](https://github.com/AdaCore/skills) at commit
`673773f4fc10224db3805befc18761c6400c460d` (plugin version 0.4.0).

They are under the Apache License 2.0. `LICENSE-adacore-skills` is a copy of the upstream license.
Do not edit these copies. Report a problem upstream.

These AdaCore skills are not copied:

- `gnattest` generates AUnit test harnesses. The Beacon tests are plain Ada
  programs in `tests/src/`.
- `gnatfuzz` needs an AdaCore Pro toolchain. CI uses the Alire toolchain.
- `gnatdoc` generates API documentation. Beacon does not generate API
  documentation yet.

### Update the AdaCore skills

1. Get the latest upstream commit:

   ```sh
   gh api repos/AdaCore/skills/commits/main --jq .sha
   ```

2. Download that commit to a temporary directory:

   ```sh
   mkdir /tmp/adacore-skills
   gh api repos/AdaCore/skills/tarball/<sha> | tar -xzf - -C /tmp/adacore-skills --strip-components=1
   ```

3. Replace the copies:

   ```sh
   rm -r .agents/skills/gnatprove .agents/skills/alire
   cp -r /tmp/adacore-skills/plugins/adacore/skills/gnatprove .agents/skills/
   cp -r /tmp/adacore-skills/plugins/adacore/skills/alire .agents/skills/
   ```

4. Write the new commit and plugin version in this file.

## Add a skill

1. Write the skill in `.agents/skills/<name>/SKILL.md`. The `name` field must
   be the same as the directory name.
2. Add a symlink for Claude Code. Run these commands in `.claude/skills/`.

   ```sh
   cd .claude/skills
   ln -s ../../.agents/skills/<name> <name>
   ```

3. Add the skill to the table in this file and to the table in `AGENTS.md`.
