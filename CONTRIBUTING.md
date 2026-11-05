# Contributing

## Who owns what

This repository is the **seed**. The AdaCore GAP coordinator maintains
it. The seed changes only to fix the seed itself, for example a wrong
contract, a build problem, or a port that does not link. The coordinator
tells you about each change, so that you can rebase. Each change will be
small.

Each capstone team works in its own **fork**. The fork is your project
for the year. You may branch, experiment, and break things there. Do not
open a pull request to this repository during the year.

At the end of the year, the coordinator merges the best work back into
the seed for the next cohort. The README and the commit history give
credit to the authors.

## Keep CI green

Your fork has the same CI workflow. The workflow does these steps:

1. Builds with warnings as errors.
2. Runs the tests.
3. Runs the demos.
4. Runs SPARK flow analysis.
5. Runs the SPARK proof of Beacon.Queue.

All steps must pass. Until Milestone 1 is done, step 5 can report
unproved checks, and CI does not fail. When you add behavior, add a test
or a proof for it in the same commit.

Do not weaken a contract or an invariant to make a check pass. If a
contract is wrong, fix the contract in a separate commit. Put the reason
in the commit message, and bring the change to the weekly meeting.

When a commit adds or changes a test, update `tests/COVERAGE.md` in the
same commit.

## Reviews

Reviews occur at the weekly meeting, on a branch of your fork. Open the
diff before the meeting.

## Style

- GNAT style (`-gnatyg`), 100 columns maximum.
- Names follow the reference that the README gives, where one exists.
- Each public subprogram has a comment. The comment states what the
  subprogram guarantees, not how it works.
- Each commit has a one-line summary in the imperative mood. Add a body
  when the summary is not sufficient.
