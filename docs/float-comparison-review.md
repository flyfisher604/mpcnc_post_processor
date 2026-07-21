# Floating-Point Comparison Review — MPCNC_v4.0_Beta2.cps

A targeted review for equality/inequality comparisons that could behave incorrectly due to
floating-point representation (e.g. `a == b` on coordinates that are "logically" equal but
differ by ~1e-12). Every `==`, `!=`, `>=`, `<=`, `<`, `>` in the file was classified by operand
type.

Legend: `[x]` fixed, `[ ]` open.

## Fixed

- [x] **FP1 — `isSafeToRapid` compared raw coordinates with `==` / `>=`.** — [`isSafeToRapid`](../MPCNC_v4.0_Beta2.cps#L833-L876). `zConstant = (z == cur.z)`, `xyConstant = ((x == cur.x) && (y == cur.y))`, and `curZSafe = (cur.z >= safeZHeight)` used the raw `onLinear` destination coords vs `getCurrentPosition()` — doubles that can differ by float noise when an axis is logically constant. Effect was a **missed optimization, not a safety risk**: it only gates converting a G1 to a G0 rapid *inside the `zSafe` zone* (a real cut below safe Z has `zSafe` false, so nothing converts), and a genuine cutting move differs by far more than epsilon (so no false "cut → rapid"). But float noise on a logically-constant axis made `xyConstant`/`zConstant` spuriously false, intermittently defeating the "Map G1s → G0 Rapids" feature. The author already rounded `z` for the `zSafe` test (`z_round`) but hadn't carried that through to the other comparisons. **Fixed** by rounding every comparison operand (`x, y, z, cur.x, cur.y, cur.z`) to the **output precision** — `unit == MM ? 3 : 4` decimals — before comparing. Positions that format to the same G-code coordinate are the same point to the machine, so this compares at the resolution that actually matters. Also fixed a latent inch bug: the old `z_round` hardcoded 3 dp; it's now unit-aware (4 dp in inch mode).

## Reviewed and cleared (no change)

- **`xyz.length == 0`** — [`limitFeedByXYZComponents`](../MPCNC_v4.0_Beta2.cps#L1761). Float-equality against zero guarding a divide-by-zero in `getNormalized()`. The dangerous case is an *exactly*-zero vector (→ NaN), which is precisely what `== 0` catches; if float noise makes it tiny-but-nonzero instead, `getNormalized()` still returns a valid unit vector and the feed math proceeds harmlessly. A `< epsilon` guard would be marginally more robust but isn't needed.
- **`_z < getCurrentPosition().z`** — [`rapidMovements`](../MPCNC_v4.0_Beta2.cps#L1729). Pure `<` ordering to choose XY-then-Z vs Z-then-XY. If the two are float-equal-ish the branch is arbitrary but harmless (both orders reach the same point; ordering only matters when Z genuinely differs).
- **`currentSpindleSpeed != _spindleSpeed`** — [`setSpindeSpeed`](../MPCNC_v4.0_Beta2.cps#L1488). RPM may be fractional, but the stored and incoming values come from the same source, so an unchanged speed is bit-identical.
- **`Math.abs(newFeed - feed) > 0.01`** — [`limitFeedByXYZComponents`](../MPCNC_v4.0_Beta2.cps#L1788). Already a correct epsilon comparison.
- **All other comparisons** are non-float: firmware/enum/string (`fw == eFirmware.X`, `name == "…"`), integers (tool numbers, work offsets, `match.length`, array indices, loop counters), `== undefined`/`== null`, boolean flags, and threshold inequalities against literals (`seconds > 99999.999`, `taperAngle < Math.PI`, `pair.max < rmax`). None are float-equality hazards.
