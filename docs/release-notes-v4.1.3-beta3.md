# Release notes: v4.1.3 Beta 3

v4.1.3 Beta 3 is a correction release for **FluidNC users**. FluidNC refused to run files from
this post, stopping at the first warning with *error 14, line too long*. This release splits long
comments and warnings over several lines so that FluidNC accepts the file. No g-code command
changed, no capability was added or removed, and **no property key moved, so your saved settings
carry over.**

Everything here changed since **v4.1.2 Beta 3**. `git log v4.1.2_Beta3..v4.1.3_Beta3` is the
changelog. The register row this release closes is `V1-1` in `docs/findings.md`, which carries the
firmware citations.

**Coming from an earlier release?** Read the [changelog](../CHANGELOG.md) entry for each release
you skipped. The v4.1.2 notes are kept at
[their tag](https://github.com/flyfisher604/mpcnc_post_processor/blob/v4.1.2_Beta3/docs/release-notes-v4.1.2-beta3.md).

- [FluidNC runs the file](#fluidnc-runs-the-file)
- [Before your first v4.1.3 job](#before-your-first-v413-job)
- [What stands behind this](#what-stands-behind-this)
- [What is not verified](#what-is-not-verified)

---

## FluidNC runs the file

**What went wrong.** The post writes warnings into the file as comments, and some of them were
long: up to 645 characters on one line. Every file posted for GRBL begins with one of them, about
600 characters, near the top of the file. Classic Grbl 1.1 ignores comment text when it checks a
line's length, so it never noticed. **FluidNC counts every character on the line, comments
included**, and stops a file job when a line reaches 255 characters. So FluidNC refused the file
before it moved, with:

```
error 14 (Line too long)
```

Some FluidNC builds word it *Startup line too long*. Deleting that one comment did not help,
because more long warnings followed it. Deleting every comment did work, which is what users on
the forum found.

**What changed.** Every comment and warning longer than 100 characters is now split over several
comment lines. The lines after the first are indented by three extra spaces, so a warning still
reads as one paragraph:

```
( >>> WARNING: the F values on the G0 moves below do not set how fast this job travels. GRBL and)
(    FluidNC ignore F on a rapid and move at the maximum rate configured for each axis, so this)
```

No line in a file from this post is now longer than 102 characters. **Only comment lines changed.**
Every move, feed, speed and code is the same as v4.1.2 would have written for the same job.

This applies to every firmware choice, not only GRBL, because shorter lines are easier to read in
any sender.

---

## Before your first v4.1.3 job

**1. Delete your old copy of the post first.** The file is `MPCNC_v4.1.3_Beta3.cps`, so it installs
beside v4.1.2 Beta 3 rather than replacing it.

**2. Your settings carry over.** No property key or value id changed.

**3. Stop deleting comments by hand.** If you were removing the warnings to get FluidNC to load a
file, post the job again with this release instead. Those warnings describe things the file does,
such as replacing a stored origin or starting without a Z reference, and they are worth reading
before you cut.

---

## What stands behind this

The regression suite is still **228 cases across six matrices, all passing**. What is new is a
check that runs on every case in the CorrectGcode matrix: **no line in the file may be longer than
254 characters.** It fails against v4.1.2 at the warning that FluidNC refused, and it passes on
every file this release produces.

## What is not verified

- **No controller was used.** FluidNC's limit and its error come from reading its source
  (`InputFile.cpp` and `Channel.h` on the main branch), and Grbl's from `protocol.c` in Grbl 1.1.
  This project has no CNC controller, no sender console and no machine time.
- **Streaming is a separate path.** When a job is streamed over a serial connection rather than run
  as a file, FluidNC's source drops the characters past the limit without reporting an error. With
  every line now well under the limit this no longer arises, but what FluidNC did with a cut-off
  comment on earlier releases was not checked.
- **No file has been posted from Fusion itself.** None of the suite's job files is an operator's
  own Setup.

`docs/findings.md` §7 is the standing list of what is owed.

## Where to read more

| | |
|---|---|
| Setting up your first job | [Hobbyist guide](guide-hobbyist.md) |
| The guards, tool changes, work offsets | [Pro guide](guide-pro.md) |
| Every setting, in dialog order | [Property reference](property-reference.md) |
| Every release | [Changelog](../CHANGELOG.md) |
| Why the post behaves as it does | `docs/design.md` |
| What was found, and what is owed | `docs/findings.md` |
| How the post is run, and what a run may claim | `docs/integration.md` |
