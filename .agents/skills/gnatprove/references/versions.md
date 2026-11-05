# Releases and manuals

## Reading the version

`gnatprove --version` prints one of:

- **SPARK Pro** `YY.N`, sometimes with `w` and a build date, e.g.
  `SPARK Pro 27.0w (20260413)`. `YY` is the release line; `N` is 0 for the
  preview (around October of the year before), 1 for the release (around
  February), 2 for the final release (around July). `w` marks a development
  wavefront.
- **SPARK FSF** `N.M`, matching the GCC release it ships with (around June).

SPARK FSF does not match any one SPARK Pro release. Its branch is usually
taken around January, so FSF `N` has every feature of SPARK Pro `N+10`.0 and
some features of Pro `N+11`: FSF 16 has all of Pro 26.0 and part of Pro 27.
It probably lacks some fixes from Pro `N+10`.1 and lacks those new in
`N+10`.2. Treat a wavefront `27.0w` as Pro 27.

## Release markers

The skill covers SPARK Pro 25 / FSF 15 and later. Material that needs a newer
release is marked:

> **Requires:** SPARK Pro 26 / FSF 16 or later.

A marker names a release line and holds for its final release (Pro 26 means
26.2). Unmarked material applies to every covered release. When the installed
release is older than a marker, do not rely on the feature; use the fallback
given with it (**Before SPARK Pro 26:** ...).

A marker's FSF release is the first that certainly has the feature. The FSF
release before it may have it too (FSF 16 may have a feature marked
Pro 27 / FSF 17). On that release, confirm on a small example that GNATprove
accepts and checks the feature before relying on it.

## Manuals for the installed release

The skill's links go to the SPARK Pro 27.0 manuals. Read the manuals for the
installed release instead:

| Installed | In the link, replace `gnat-27.0` with |
|---|---|
| SPARK Pro `YY.N` (e.g. `26.1`) | `gnat-YY.N` (`gnat-26.1`) |
| SPARK FSF `N.M` (e.g. `15.1`) | `gnat-<N+10>.0` (`gnat-25.0`); a feature missing there may be in `gnat-<N+11>.0` |
| a wavefront newer than the latest release | use `https://docs.adacore.com/live/wave/` in place of `https://docs.adacore.com/R/docs/gnat-27.0/` |

A section missing from your release's manual documents a feature that
release does not have.

Entry points (27.0):

- [SPARK User's Guide](https://docs.adacore.com/R/docs/gnat-27.0/spark2014/html/spark2014_ug/index.html):
  how to write SPARK, run GNATprove, and read its output.
- [SPARK Reference Manual](https://docs.adacore.com/R/docs/gnat-27.0/spark2014/html/spark2014_rm/index.html):
  the language rules: what is legal and what is checked.
- [GNAT Reference Manual](https://docs.adacore.com/R/docs/gnat-27.0/gnat_rm/html/gnat_rm/gnat_rm.html):
  GNAT pragmas, aspects and language extensions.
- [Command-line reference](https://docs.adacore.com/R/docs/gnat-27.0/spark2014/html/spark2014_ug/en/appendix/command_line_invocation.html):
  every switch and the prover limits of each `--level`.
