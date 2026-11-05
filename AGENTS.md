# AGENTS.md

This file gives instructions to coding agents in this repository.
`README.md` describes the design. `CONTRIBUTING.md` gives the rules for
changes. This file does not repeat them. Read both before you change code.

## Skills

The skills are in `.agents/skills/`. If your agent does not load skills, read
the `SKILL.md` file of the skill before you start the task.

| Task                                                            | Skill           |
| --------------------------------------------------------------- | --------------- |
| Write or change docs, Ada comments, commit messages, or PR text | `writing-style` |
| Write, change, or prove SPARK code, or run GNATprove            | `gnatprove`     |
| Change `alire.toml`, a dependency, or the toolchain             | `alire`         |

## Build and test

`.github/workflows/ci.yml` is the source for these steps. Run them from the
repository root. Each step must pass before you report that a change is done.

1. Build the library:

   ```sh
   alr -n build
   ```

2. Build the embedded profile, without `src/net/`:

   ```sh
   BEACON_NETWORK=no alr -n build
   ```

3. Build and run the tests:

   ```sh
   cd tests
   alr -n build
   ./bin/queue_tests
   ./bin/topic_tests
   ./bin/wire_tests
   ```

4. Build and run the in-process demo:

   ```sh
   cd demo
   alr -n build
   ./bin/inproc_demo
   ```

5. Run SPARK flow analysis and the proof from the `prove/` crate:

   ```sh
   cd prove
   alr -n exec -- gnatprove -P ../beacon.gpr --mode=flow --checks-as-errors=on
   alr -n exec -- gnatprove -P beacon_prove.gpr --mode=all --checks-as-errors=on
   ```

   Flow analysis must pass. Until Milestone 1 is done, the proof can
   report unproved checks.

## Rules

- The compiler treats warnings as errors (`-gnatwe`). Fix the cause of a
  warning. Do not suppress it.
- Do not weaken a contract, an invariant, or a test to make a check pass.
- This repository is a fork. Open pull requests against `ge-garcia/beacon`.
  Do not open a pull request against `GNAT-Academic-Program/beacon`.
