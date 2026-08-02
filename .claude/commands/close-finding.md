---
description: Land a finding and its register row in one commit
argument-hint: "<finding id, e.g. HR-24 or CR-15>"
---

Close finding **$1** in `MPCNC_v4.0_Beta2.cps`.

This is the register procedure from `CLAUDE.md` → *Registers ship with the code*. Both halves are
required, and the register row lands in the **same commit** as the code — not after it.

1. **Locate it.** Find $1's row in `docs/HReview.md` or `docs/PReview.md`. Read the row before the code:
   it states what the fix has to be true of. If $1 appears in both files, the register that owns it is
   the one matching the persona — hobbyist is one part, one WCS, one tool, several operations;
   professional is multi-WCS, spoilboard base, tool changes, Manual NC, the dialog.

2. **Show the diff before applying it.** Every time, including one-liners. Proposing and applying are
   separate steps. Count the call sites in the code before believing the diff is complete — *every* fix
   so far has deviated from its proposal the same way, by understating how many there were.

3. **Add the Do→Get row** to the test register: exact dialog settings as a delta from the defaults in
   `conventions.md` → *How to run a test*, an exact expected g-code block, and a Pass line naming the
   **discriminator** — the one token whose presence or absence proves it, and often an *absence*. Cover
   **both branches** of any new condition: the one that emits and the one that suppresses. Write every
   criterion as something visible in the file.

4. **Flag what the change invalidates.** Any `PASS` row whose saved `.gcode` no longer matches goes in
   the *Invalidated by …* table, which is deleted row by row as those tests are re-posted.

5. **Retire the long form.** On FIXED or closed-by-design, delete the write-up and leave the register
   row. `git show <commit>` holds the buggy code, the diagnosis and the diff. Long form is a promissory
   note, justified only while the work is unbuilt.

6. **Commit.** One message describing **the code change and why** — never the doc bookkeeping. The
   pre-commit gate re-counts the tallies and the id completeness; if it aborts, fix the register rather
   than the number it complains about.

Do not ask whether to add the row. Add it.
