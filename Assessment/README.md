# Assessment — what is left of it, and what a dead pointer means

The analysis this project's plan came from, run 2026-08-08 to 2026-08-13. **Read it for
evidence and for what the post is *for*, never for where things live** — its file and line
pointers predate two consolidations and a version.

## The four pages that remain

| | |
|---|---|
| `01-personas.md` | Who uses this post — P1 to P7, the hardware and firmware landscape behind them, and the four operator-practice questions nothing but an operator can answer. **Live**: `tools/hobbyist-matrix.js` and `tools/professional-matrix.js` name it as the source of P1/P2, and `plan.md` parks group 9 on a persona ruling that belongs here. |
| `02-z-trust.md` | Why *"Z is untrusted"* was half wrong, and the distinction underneath it. The argument behind the retired spoilboard base; `design.md` → *Frames* is the shipped version of the model. |
| `04-user-stories.md` | What the post is for, as stories. **Frozen** — nothing in it may be revised to fit code found later, which is why it is still worth reading. The only place `S`-numbers resolve. |
| `08-target.md` | The scope decision the rest was built to: S12, multi-part and multi-fixture, in scope for the hobbyist full-licence user. |

## Six pages were retired 2026-08-20

**A reference anywhere in this folder to one of these is a dead pointer, not a missing
file.** Recover any of them with `git log -p -- Assessment/`.

| Retired | Why, and where its conclusions live now |
|---|---|
| `00-facts-needed.md` | Its job A/B/C questions asked a human to observe what arrives at a post's callbacks. The integration suite now observes it directly — `tools/trace.cps` records every callback the kernel raises, over Autodesk's own `.cnc` library — so `integration.md` is the answer to the whole page. `E1` closed from Marlin source and is `design.md`'s two rows on `coordinate_system[]` and `position_shift`. **`D1`–`D4` were the only part with no other home and are now the last section of `01-personas.md`.** |
| `03-f360-and-firmware.md` | Its method was to infer what F360 supplies by reading Autodesk's 490 bundled posts. That inference is superseded by measurement: `trace.cps` reads the callbacks themselves. Its firmware half is in `design.md`, every claim cited by file and version. |
| `05-history.md` | Reviewed `docs/HReview.md`, `docs/PReview.md` and `Coverage/`, none of which exist. Its verdict — rigour applied to a problem never shown to be real — landed as the spoilboard retirement, recorded in `design.md`. |
| `06-retention.md` | *What must survive any pruning*, measured over 35 commits since `v4.0_Beta2`. The pruning is done and two releases old; its Tier 2 firmware facts are all in `design.md` and `findings.md` with citations. |
| `07-code-map.md` | Every measurement is a line span in `MPCNC_v4.0_Beta2.cps`, a file two versions gone. Its group verdicts were executed as plan steps 2, 6 and 7. |
| `10-project-cleanup.md` | Its schedule was Phase C of `09-plan.md`, itself retired at `d6fe379`. Every item is done or has moved into `plan.md`'s *Parked* table. |

**What the tree carries instead**: `docs/plan.md` says what is next, `docs/findings.md` what
was found and what is owed, `docs/design.md` why the post behaves as it does, and
`docs/integration.md` how the post is run and what a run may claim.
