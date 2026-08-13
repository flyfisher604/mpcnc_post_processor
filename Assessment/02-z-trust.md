# Step 2 — "Z is untrusted": what is actually true, and what follows

## The claim, restated

Parts of this project assume these machines generally lack Z homing, and build
logic on that. I was asked to verify rather than accept it. **The claim is now
half wrong, and the half that is wrong matters less than the confusion
underneath it.**

## Two different things called "Z"

This is the distinction to get straight first, because I think conflating them is
the root of the problem.

**Machine Z** is where the axis is in the machine's own frame. It becomes known
by homing to a switch. It is repeatable and it is the same for every job on that
machine. Its purpose is knowing the physical limits of travel — how far up the
axis can go before hitting the frame.

**Work Z zero** is where the cut depths are measured from: usually the top of the
material, sometimes the spoilboard. It has nothing to do with switches. It is
established per job by touching the bit to the surface and declaring "this is
zero", or by probing to a plate. It changes with every new piece of stock.

A machine can have *perfect* machine-Z knowledge and still have no idea where the
top of your material is. Homing does not give you work zero, and work zero does
not require homing. Every safety question in this post is about one or the other,
and they need separate answers.

## What is true per machine class

- **LowRider V4 has two Z endstops as standard**, and V1 documents Z homing
  (`$HZ`) and Z probing as standard features. `[DOC]` docs.v1e.com/lowrider,
  docs.v1e.com/electronics/jackpot. So "these machines cannot home Z" is **false
  for the current flagship**.
- **MPCNC** offers serial-wired (single endstop per axis) and dual-endstop
  configurations. `[DOC]` docs.v1e.com/electronics/marlin-firmware. Homing is
  available; whether a given build has a Z switch wired varies.
- **Comparable GRBL machines** (Shapeoko, X-Carve, Onefinity) ship homing
  switches on current models. `[COMMUNITY]`

But the decisive fact is not about hardware at all:

> *"You can now use the machine in two ways. Quick one off jobs, setting the tool
> position by hand, starting with `G92 X0 Y0 Z0`, and just running the job, or by
> starting each job with a `G28` (home and auto square)."*
> `[DOC]` docs.v1e.com/electronics/dual-endstops

**The vendor documents not-homing as a normal way to work, on machines that are
fully capable of homing.** So the post cannot assume homed, and cannot assume
un-homed. What it faces is not a machine class — it is a *per-run state* that the
post cannot observe.

## What "Z untrusted" concretely means for the operator

Asked for plainly, because this is the bit that is hard to picture:

1. The operator powers on. The controller has no idea where anything is; it
   simply calls wherever the bit happens to be sitting "zero" (GRBL/FluidNC), or
   holds an explicitly unknown position (Marlin with homing configured).
2. They jog the bit over the workpiece by eye, wind it down until it just touches
   the surface — paper-shim, or by feel — and zero the axes. On FluidNC that is
   `G10 L2 P0 Z0`; on Marlin `G92 Z0`. `[DOC]` docs.v1e.com/lowrider
3. From that instant, **work Z is trustworthy and machine Z is not**. The
   controller will happily accept `Z-3` (3 mm into the material) and get it right.
   Ask it to go to a specific *machine* height and there is no such thing —
   nothing has ever told it where the frame is.
4. What goes wrong: a command that means "lift to a known safe height above the
   table" has no meaning. `G53 Z-5` on an un-homed GRBL machine is not safe-ish
   or approximately right; it is arbitrary. It might drive the Z axis up into its
   endstop and grind, or down through the workpiece. **A relative lift — "go up
   20 mm from wherever you are" — is always meaningful.** An absolute machine
   height is meaningful only after homing.
5. Second failure, subtler: the operator homes *after* setting work zero, or power
   cycles mid-session, and the two references silently disagree.

## Both readings of the design question, then a verdict

**The case that Z uncertainty justifies more logic in the post.** The post is the
only component that knows the whole program in advance. If it can compute a
retract that is safe under either reference, it protects a beginner who cannot
read G-code from a crash. F360 emits heights relative to the *work* frame with no
idea whether the machine is homed; only the post can bridge that.

**The case that it justifies less.** A safe absolute height cannot be computed
from information the post has. The post does not know whether the operator homed,
where the frame is, how thick the stock is, or where the bit was parked. Any
absolute figure it emits is a guess wearing the costume of a safety feature — and
the more elaborate the computation, the more it reads as authoritative. A
relative retract needs no knowledge and is always correct. **The uncertainty is
not resolvable by computation; it is only resolvable by information the operator
has and the post does not.**

**Verdict: the second reading is right, with one carve-out.**

The post has no business emitting absolute machine-Z positions unless something
in the job establishes the machine frame within that same program. Where it
cannot, the correct output is a relative retract, and the correct handling of the
uncertainty is to *say so* — a warning in the file and at post time — not to
compute around it. Computing a "safe" absolute height from unknowns manufactures
exactly the false confidence a beginner cannot detect: the number looks
deliberate, so it gets trusted.

The carve-out: if the program itself homes (the post emits `G28`/`$H` at job
start, which is a documented workflow), then from that point machine Z *is*
known, and absolute machine-frame moves are legitimate **for the remainder of
that program**. That is a real capability worth keeping, and it is conditional on
something the post can actually verify — it emitted the homing command itself.

## Consequences to carry forward

1. **A "safe Z" that is absolute and unconditional is wrong** regardless of how
   it is computed. Flag any such logic in step 7.
2. **A "safe Z" that is conditional on the post having homed in this program is
   defensible.** Check whether the existing code makes that distinction or
   collapses it.
3. **Relative retract needs no configurability.** If there are properties letting
   the operator tune an absolute clearance height, ask what the operator is
   supposed to know that would let them answer correctly. If the honest answer is
   "nothing", the control is transferring a decision the post cannot make onto
   someone who cannot make it either.
4. **The distinction between machine Z and work Z should be visible in the code's
   own vocabulary.** If one variable or property name serves both, that is where
   the confusion lives.
5. **Group 5 ("Fixed Z Reference — multi-part jobs only") is exactly this
   question in its hardest form** and must be judged against this section, not on
   its own terms.

## What I could not settle

Whether F360 itself supplies a clearance height the post could simply pass
through — which would make most of this moot. That is `A1`–`A3` in
`00-facts-needed.md`, and step 3 addresses it from `[SDK]` evidence.

---

## Confirmed 2026-08-13 — this section's conclusions now have evidence behind them

Written before reading the post, and it turns out the post already implements the
recommendation. Three confirmations and one sharpening.

**1. The warn-don't-compute mechanism exists and is observable.** `[POSTED]`
`HB-13(A)-off.gcode` carries this into the file, in full:

> `( >>> WARNING: no Z reference is established, so the XY move below runs at whatever height the tool is holding -- it must be clear of the stock, clamps and fixtures before the program starts. …)`

And `HB-9(A).gcode` opens with *"`Home at Job Start` is on but `Axes Homed and
Trusted` is None -- nothing was homed."* **This is exactly what this section argued
for, already built and already emitting.** It should be extended, not replaced.

**2. F360 has a machine-frame safe Z, and it is empty.** `getRetractPlane()` **is** a
machine-frame Z, used with `G53` alongside `getHomePositionX/Y()` in 243 of 490 posts.
But `retractPlane` appears in **0** of 211 cached machine definitions and
`setRetractPlane` is commented out in all 159 posts that mention it
(`03-f360-and-firmware.md` §1a). **So `A1`–`A3`'s answer is: F360 has the slot and no
way for an operator to fill it.** Recommendation 3 above is therefore **withdrawn** —
a property asking for a machine-frame travel height is the only place that number can
come from, and it is not transferring an unanswerable decision. The operator *does*
know how tall their fixtures are.

**3. Recommendation 5 is answered, and against Group 5.** Judged against this section,
the spoilboard base fails on the section's own test: it manufactures an absolute frame
by probing whatever happens to be under the tool, and its documented failure mode is
that *"parking over the stock records the stock top as 'the spoilboard'"* — a computed
number that looks deliberate and therefore gets trusted, which is precisely the failure
this section says a beginner cannot detect. `07-code-map.md` retires it.

**4. The sharpening — why a warning and not an error.** The author asked whether the
post should simply refuse when there is no machine Z. The distinction this section was
reaching for is:

> **A relative retract is *exact*. Only its *sufficiency* is unknown.**

`G91` / `Z+n` / `G90` moves up from wherever the tool is, which the controller always
computes correctly. What no one can know is whether *n* clears the fixture. So the
uncertainty is not in the arithmetic — it is in the world, and only the operator can
see the world. That is why a warning is right for a single-WCS job, and why an **error**
is right for a multi-WCS job, where clearing one fixture says nothing about the next.
`04-user-stories.md` S8 carries the full argument.
