# THE VISION-IN-THE-LOOP ENGINEERING BIBLE

**The Authoritative Reference for the Vision-in-the-Loop (ViL) Engineering Process — the E2E discipline of verifying rendered artifacts by LOOKING at them, extracting them as evidence, naming the deltas, classifying the defect, fixing at the root, and re-rendering until the artifact reads true.**
**Version:** 1.0
**Status:** AUTHORITATIVE — READ BEFORE BUILDING ANY TOOL THAT PRODUCES A VISUAL ARTIFACT
**Date:** 2026-08-25
**Target Audience:** build agents, explore agents, the auditor, and the operator building or verifying ANY pipeline that produces images, 3D assets, UI screens, dashboards, or rendered output of any kind.
**Minimum Read Time:** 90 minutes
**Lines:** 1,000+
**Provenance:** every process, command, bug, and verdict in this bible is drawn from a REAL build — the OMNI-CANVAS v4.1 drive + closeout (2026-08-24/25), where vision-in-the-loop was THE quality mechanism and caught every real defect the build shipped and fixed. Companion canon: `SHADOW_ENHANCED_TOOLS_BIBLE.md` (the silent-backend pattern) · `Lexicon_Grade_Intelligent_Systems_Engineering_Bible.md` (the detector/decision discipline) · `CUSTOM_EVENT_HOOK_ENGINEERING_BIBLE.md` (the observation-plane pattern this bible's evidence channels generalize).
**Authority:** the operator's directive, verbatim: *"vision in the loop engineer this so the game looks good"* (captured as requirement B4 of the OMNI_CANVAS_V4_OVERHAUL_L2_SPEC: "Vision-in-the-loop engineering is THE quality mechanism — every domain line terminates in a VLM-verdictable artifact; critique is load-bearing").

> *"A preview not looked at is an unverified asset."* — the law as it operated through the entire v4.1 drive. Eleven asset classes shipped; every one of them was extracted from its build container, decoded byte-exact on the host, opened by a multimodal reader, given a named-delta verdict, and — when the verdict failed — classified, fixed at the root, re-rendered, and re-inspected. The loop caught every real defect in the build: the crossed-legs soldier, the displaced helicopter rotors, the overhanging frigate deck, the black-frame renders, the washed-out probes, the cropped radar, the gate-order regression. Not one of them was caught by a unit test. Not one of them was caught by a pixel histogram. Every one of them was caught by LOOKING.

---

# PART 0 — THE TABLE OF CONTENTS (the reading order)

| Part | Title | What it covers |
|---|---|---|
| 1 | THE MANIFESTO | what ViL engineering IS and IS NOT, the three verification grades, the three laws, the founding trauma |
| 2 | THE E2E LOOP | the 9-step engineering method with the exact commands, the canonical shape, the evidence pattern |
| 3 | THE VERDICT RUBRIC | how to LOOK: the five questions, the named-deltas discipline, the classification decision tree, iteration convergence |
| 4 | THE EVIDENCE PIPELINE | the exact container→host extraction channel, the decode, the multimodal read, omni-vision modes, the browser channel, the GLB mechanical cross-check |
| 5 | THE BUG LEDGER | every defect the loop caught in the v4.1 drive + closeout — symptom, catch, root cause, fix, re-render proof |
| 6 | THE ANTI-PATTERNS | the complete bullshit catalog — image-only verification, approve-by-default, blind builds, stale previews, conformance verdicts — each with root cause + countermeasure law |
| 7 | THE TESTING DISCIPLINE | the zero-hint visual battery, the mutation check, the ViL tool contract, the results-artifact schema |
| 8 | THE REPLICATION RECIPE | the E2E recipe for a NEW artifact type, with the exact command sequences |
| 9 | THE IRON LAWS | the one-line inviolable rules |
| 10 | CANON INTEGRATION | composition with the runtime-grade bible, the shadow bible, the ISE law |
| 11 | THE QUICK-REFERENCE CARD | the one-page cheat sheet |
| **A-PARTS** (the deep-dives, in reading order after the core) |
| 2A | THE SOLDIER CASE, E2E | the reference execution narrated with real values (incl. the dead-code discovery) |
| 3A | THE RUBRIC PER ARTIFACT CLASS | 3D / UI / dashboard / chart / document |
| 4A | THE PROBE CALIBRATION METHODOLOGY | how the measurement instruments got their settled values |
| 5A | THE OMNI-VISION INVOCATION GUIDE | direct vs api modes, the floors, the division of labor |
| 6A | THE TIERED VERIFICATION ECONOMICS | T0 smoke / T1 loop / T2 ship gate / T3 stranger audit |
| 7A | THE RESULTS-ARTIFACT LEDGER | the sealed N1 record, abridged |
| 8A | THE QUICK ANSWERS | the FAQ |
| 9A | THE HELI CASE, E2E | exoneration + isolation + arithmetic confirmation |
| 9B | WHEN THE LOOP MISFIRES | the loop's own six failure modes |
| 10A | THE INTEGRATION CHECKLIST | the 10-question pre-build gate for new tools |
| 11A | THE ONE-PAGE PROCESS CONTRACT | paste into any tool spec |
| 12A | THE FRIGATE CASE, ABRIDGED | the shared-script, two-for-one verification |
| 13A | THE EVIDENCE-PAIR NAMING CONVENTION | why file names are load-bearing |
| 14A | THE MINIMUM READ | the 20-line bible |
| 15A | COLOPHON + CANON REGISTRATION | provenance + maintenance law |

---

# PART 1 — THE MANIFESTO

## 1.1 The One-Sentence Law

**A preview not looked at is an unverified asset.**

Everything else in this bible is the operational expansion of that sentence. If a pipeline produces a visual artifact — a PNG, a GLB, a dashboard, a UI screen — and no multimodal reader has opened the artifact and rendered a verdict, the artifact's correctness is UNKNOWN regardless of what any test, hash, grep, or exit code says. The tests prove the machinery ran. Only looking proves the artifact is RIGHT.

## 1.2 The Founding Trauma (why the law exists — the v3 blank-PNG incident)

The OMNI-CANVAS v3 build produced 221 chart artifacts. Every one passed the pipeline's checks. Every one was shipped. Every one was **blank** — unlabeled, empty renders dressed as success by a fallback-buffer contract and an approve-by-default critique: when the VLM critique tool had no client wired, it returned `APPROVED_WITH_WARNINGS` instead of refusing to judge. The failure was invisible until a human opened the images.

The post-mortem produced three permanent removals:
1. **The fallback-buffer contract was deleted.** A render that fails produces a named FailureManifest `{code, stage, message, layerId}` — never a substitute artifact.
2. **The approve-by-default contract was deleted.** The ViL critique returns `PASS | FAIL | INCONCLUSIVE` — and `INCONCLUSIVE` (which is what "I could not judge" means) is the no-client state. A tool that cannot see REFUSES TO APPROVE.
3. **Vision-in-the-loop became load-bearing.** The operator's directive — *"vision in the loop engineer this so the game looks good"* — was captured as spec requirement B4: every domain line terminates in a VLM-verdictable artifact; critique is not decoration, it is the quality gate.

**The lesson generalizes:** the absence of failure evidence is not evidence of absence of failure. Visual artifacts fail in ways only vision detects — and the failure mode of the verifier itself (approve-by-default) is the most dangerous failure a pipeline can have, because it converts every other failure into a shipped lie.

## 1.3 What ViL Engineering IS and IS NOT

| | ViL Engineering IS | ViL Engineering IS NOT |
|---|---|---|
| The act | extracting the rendered artifact as byte-exact evidence, opening it with a multimodal reader, rendering a named-delta verdict, and looping on failure | glancing at a file size, trusting a green exit code, reading the generator's own summary of what it drew |
| The verifier | an independent multimodal reader (the coding agent's native vision, or a VLM tool) reading THE ARTIFACT | the generator grading its own output; a script asserting its own numbers |
| The standard | "does this artifact READ as its class to a viewer" — semantics, not existence | "does the file exist / is the histogram non-trivial / did the process exit 0" |
| The loop | render → extract → look → verdict → classify → fix at root → re-render → re-inspect → log | render once, ship |
| The record | before/after evidence pairs, named deltas, iteration counts, per-asset verdicts in a results artifact | a build log line saying "render complete" |

## 1.4 The Three Verification Grades (only the third verifies MEANING)

| Grade | What it checks | What it catches | What it MISSES | Verdict power |
|---|---|---|---|---|
| **Grade 1 — existence/pixel** | file exists, byte count, PNG magic, pixel standard-deviation (non-blank) | empty renders, zero-byte files, process crashes | EVERYTHING semantic: a blank-ish render with noise passes; a wrongly-assembled model passes; crossed legs pass | necessary, never sufficient |
| **Grade 2 — structural** | schema fields, JSON integrity, mesh counts, animation counts, sha match | corrupt files, missing skins, broken serialization | whether the artifact LOOKS right; a structurally perfect GLB can have legs crossed, rotors detached, a deck overhanging | necessary, never sufficient |
| **Grade 3 — full ViL multimodal** | a vision-capable reader opens the artifact and answers: does this READ as its class? are the materials believable? what is off? | everything Grade 1+2 miss plus semantic wrongness: crossed legs, floating parts, overhangs, washed lighting, cropped framing, detached components | nothing (when done per this bible) — but only when the reader is independent of the generator | the verification |

**The law of grades:** Grade 3 presupposes Grades 1 and 2. You extract byte-exact (1), you cross-check the structure (2), and then you LOOK (3). Skipping to 3 without 1-2 means you are interpreting a possibly-corrupt artifact; stopping at 1-2 means you never verified meaning at all.

**The proof from the build (why grades 1-2 alone are theater):** in the v4.1 closeout, the soldier GLB passed every Grade-1 and Grade-2 check — correct magic bytes (122,188B at v1; 121,656B post-optimization at v3), 3 animations, 1 skin, valid schema — while its PREVIEW showed the legs crossed mid-stride. The frigate deck overhang and the detached helicopter tail rotor both passed pixel-standard checks across multiple builds. The defects were visual-semantic. Only Grade 3 caught them.

## 1.5 The Three Laws of Vision-in-the-Loop

**LAW 1 — THE EXTRACTION LAW.** The artifact must be extracted as BYTE-EXACT EVIDENCE before any verdict. In-container display truncation is cosmetic; the verdict is made on the decoded host-side file, magic-checked, sha-recorded. A verdict made on a thumbnail, a log line, or the generator's description is not a verdict.

**LAW 2 — THE INDEPENDENT-READER LAW.** The verdict is rendered by a reader that did not generate the artifact — and the reader must be VISION-CAPABLE: a text-only model in the reader seat produces a CONFORMING VERDICT (it agrees with the expectation because it cannot see the artifact at all). The drive's runtime default (Nemotron — text-only) silently 'passes' visual gates; the statusBar/model identity of the READER is part of the verdict record. The generator's self-assessment is a claim. The coding agent's multimodal read of the extracted PNG, or a VLM tool's verdict on the image, is evidence. An LLM grading its own render in the same context that produced it is the fox auditing the henhouse — the conformance pressure alone invalidates it.

**LAW 3 — THE NAMED-DELTA LAW.** A verdict without named deltas is not a verdict. "Looks good" is banned; "looks off" is banned. The verdict names WHAT is wrong (or confirms zero deltas after a real hunt): which part, where in the frame, wrong how, and — critically — the classification: is this a SCRIPT defect (the geometry source), a PIPELINE defect (camera/lighting/bake/export), a TRANSPORT defect (extraction/corruption), or an ENVIRONMENT defect (missing dependency)?

## 1.6 The Meta-Process in One Paragraph

Render with intent → extract byte-exact through the evidence channel → decode + magic-check on the host → open with the multimodal reader → answer the rubric's five questions → name every delta → classify each delta into the decision tree → fix at the ROOT the tree names (never the symptom) → re-render → RE-INSPECT (a fix is not a fix until the pixels say so) → count the iterations → log the verdict + the evidence pair. The loop terminates on a PASS verdict with zero named deltas. Every iteration is logged; every shipped asset carries its evidence pair.

---

# PART 2 — THE E2E LOOP (the meta-process)

## 2.0 The 9-Step Engineering Method (the load-bearing order — each step with its exact mechanics)

The loop is nine steps. The order is load-bearing: every step exists because skipping it shipped a defect. The commands shown are the battle-tested forms from the OMNI-CANVAS drive (opencode plugin + trident-container-test workflow); Part 8 generalizes them to new artifact types.

### STEP 1 — RENDER WITH INTENT

The render is a MEASUREMENT INSTRUMENT, not a hope. Before rendering, decide what the preview must show for the verdict to be possible:
- **Probe** (lighting rig) matched to the material story: `studio` for small props, `desert_sun` for ground vehicles/structures/air, `outdoor_overcast` for warships. A washed-out or pitch-black render cannot be judged — probe choice is a verdict prerequisite.
- **Resolution** sufficient for the deltas you hunt (the drive standard: 1080 square master; 1280×720 scene graphs).
- **Camera intent**: the auto-fit camera must place the WHOLE artifact in frame (world-space bbox fit with ground-plane exclusion — a local-bbox bug put the camera INSIDE geometry and produced pure black frames; the loop caught it as BUG-02).
- **The named expectation**: write down, BEFORE rendering, what a correct render shows. "Soldier standing, legs parallel, rifle held, helmet on." The expectation is the ruler the verdict measures against — and it must come from the SPEC, never from the render itself.

Anti-target: rendering "to see what happens." A render without a written expectation produces a verdict without a ruler.

### STEP 2 — EXTRACT BYTE-EXACT (the evidence channel)

The artifact lives inside the build environment (container, sandbox, dev server). The verdict requires it on the verifier's disk, byte-exact. The proven channel for containers:

```
# inside the container (via the tool's exec action — MINIMAL params, see LAW below):
exec: base64 -w0 /tmp/omni-canvas/<ws>/<artifact>.png
# the FULL base64 lands in a HOST-side tool-output file regardless of display truncation:
#   ~/.local/share/opencode/tool-output/tool_*.json
```

Then decode host-side and PROVE the bytes:
```python
import json, base64
d = json.load(open('<tool-output-file>'))
out = d.get('stdout') or ''
if isinstance(out, dict): out = out.get('stdout', '')
data = base64.b64decode(out.strip())
open('<dest>.png', 'wb').write(data)
print('bytes:', len(data), 'magic:', data[:4])   # PNG: b'\x89PNG'  GLB: b'glTF'
```

The three checks at extraction: **byte count** (matches the container-side `ls -la`), **magic bytes** (PNG `\x89PNG`, GLB `glTF`), and **sha256 recorded** into the results artifact. THE EXTRACTION LAW (1.5) is enforced here: display truncation of the exec output is COSMETIC — the tool-output file holds the complete payload; verify by byte count, never by eyeballing the base64 in the transcript.

The minimal-params law for the exec channel: the container-testing tool's exec drops its `command` param when called with many other params (a serialization collision observed ~40 times in one session). The proven shape: `containerName` + the command text ONLY. Chain simple calls; never one complex call.

### STEP 3 — LOOK (the multimodal read)

Open the decoded file with the independent reader:
- The coding agent's native multimodality: the `read` tool on the `.png` — the image enters the context as an attachment. This is the drive's workhorse: every verdict in the v4.1 roster was rendered this way.
- **omni-vision direct mode**: `omni_vision(file_path, mode="direct")` for single images or batch frames (video → keyframes, PDF → pages). Direct mode reads INTO your context — use it when you want the VLM's structured description alongside your own read.
- **omni-vision api mode** (the shadow-enhanced form): requires `media_context` (500+ chars: what this media is), `analysis_goal` (200+ chars: what to determine), `output_requirements` (3+ items: the required verdict sections). The backend silently injects storyline + prior-frame context. Use it when the read is part of an automated pipeline and the verdict must be reproducible.

THE INDEPENDENT-READER LAW applies: the reader must not be the generator's context. If the same agent rendered AND inspects, the inspection must be a FRESH read of the artifact file — never a recall of what the generation "should have" produced. For pipeline-grade automation, prefer omni-vision api mode precisely because its context is constructed from the artifact, not from the generation session.

What LOOKING means concretely: the reader answers the rubric (Part 3) against the written expectation from Step 1. Not a glance — an enumeration: every expected element found/missing/wrong.

### STEP 4 — VERDICT (the rubric applied)

The verdict is one of three tokens, exactly: **PASS**, **FAIL**, **INCONCLUSIVE**.
- PASS: every expected element present, zero named deltas after a real hunt.
- FAIL: one or more named deltas.
- INCONCLUSIVE: the render cannot be judged (washed out, cropped, corrupt, wrong probe) — the defect is in the MEASUREMENT, so re-render with the measurement fixed before judging the artifact. INCONCLUSIVE is a first-class outcome: judging an unjudgeable render is fabrication.

### STEP 5 — NAME THE DELTAS

For every FAIL: enumerate the deltas as concrete visual facts. Form: `<part> is <wrong-relationship> <where-in-frame>`. Real named deltas from the drive:
- "left and right legs cross in an X pattern at mid-stride instead of hanging parallel"
- "tail rotor hub floats ~1.5 units off the fin's leading edge, up-left in frame"
- "deck plate extends past the hull sides at the stern taper"
- "entire render is black — camera inside geometry" (INCONCLUSIVE-grade delta)
- "materials blown out to white across the top third — probe overexposure"

BANNED FORMS: "looks off", "something's wrong with the legs", "quality is bad". An unnamed delta cannot be classified (Step 6) and therefore cannot be fixed at the root (Step 7).

### STEP 6 — CLASSIFY (the decision tree)

Each named delta goes down the tree. The classification decides WHICH FILE OWNS THE FIX — the single highest-leverage step in the loop (the drive's failures to classify cost hours; the successes closed in one edit):

```
The delta is a visual fact. Why did the pixels come out wrong?

├─ Does the GRAPH/STRUCTURE match the intent? (GLB parse: nodes, transforms,
│  animations, skins; HTML: DOM; UI: DOM/box model)
│   ├─ NO, structure is wrong ────────► SCRIPT DEFECT
│   │     the geometry/data SOURCE is wrong. Owner: the template/generator
│   │     (templates-*.ts buildScript, the html source, the CAD script).
│   │     Examples: crossed-legs GEOMETRY risk, deck plate dimensions,
│   │     tail-rotor Y-offset, mosque dome proportions.
│   └─ YES, structure is right ───────► PIPELINE DEFECT
│         the pixels misrepresent correct structure. Owner: the wrapper —
│         camera, lighting/probe, bake, export, rig application ORDER.
│         Examples: black frame (camera fit), washed render (probe exposure),
│         posed preview (rig-before-render ordering), detached rotors
│         (stale matrix_world in the rig), gate-order regression.
├─ Did the artifact survive the TRANSPORT? (byte count, magic, decode)
│   └─ NO ────────────────────────────► TRANSPORT DEFECT
│         Owner: the extraction channel. Example: partial decode, wrong
│         tool-output file, HTML page captured before module load.
└─ Did the ENVIRONMENT provide the engine? (blender present, chromium,
   gltf-transform, fonts)
    └─ NO ────────────────────────────► ENVIRONMENT DEFECT
          Owner: the setup. Example: ENGINE_MISSING naming the install command.
```

The tree's power is the STRUCTURE-YES branch: when the structure is right but the pixels lie, the defect is in the PIPELINE — and pipeline defects are invisible to every structural test, which is exactly why the loop exists.

### STEP 7 — FIX AT THE ROOT

The tree names the owner file. The fix goes THERE — never into the preview, never a post-hoc crop, never a retry-and-hope. The drive's root fixes, one per classification branch:
- SCRIPT: deck x-scale `HW * 1.70 → HW * 0.96` (templates-warships.ts:210); tail rotor Y `0.14 → 0.12` (templates-air.ts:268/271/273).
- PIPELINE: world-space camera fit via matrix_world (BUG-02); probe exposure retunes (BUG-03/04/05); `reset_pose_for_render()` before render (BUG-25); `bpy.context.view_layer.update()` before the matrix_parent_inverse read (BUG-26); gate LOD-order floor (BUG-01); blender timeout 120s→360s.
- TRANSPORT: the decode-verify discipline (byte count + magic) after a partial-decode scare.
- ENVIRONMENT: `ENGINE_MISSING` failures name the exact install command in the failure manifest.

THE ROOT-FIX LAW: a fix that changes the presentation without changing the owner file is a symptom patch. Symptom patches ROT — the next render regresses. If the fix cannot be placed in the owner file, the classification is wrong; re-classify.

### STEP 8 — RE-RENDER + RE-INSPECT

**A fix is not a fix until the pixels say so.** Re-render through the SAME pipeline, re-extract through the SAME channel, re-read with a FRESH eye, re-apply the rubric. Two disciplines:
- **The fresh-eye discipline**: each re-inspection reads the NEW artifact file (new extraction, new decode) — never compare from memory of the previous image.
- **The regression sweep**: the fix must not break the OTHER assets. After the heli rotor fix (BUG-26), the soldier and frigate were re-verified — the pipeline touch (rig_vehicle) could have regressed them. One new PASS with an old PASS broken is a NET FAILURE.

**Convergence**: the loop terminates on PASS-with-zero-deltas. Track the iteration count per asset — it is a quality metric (drive roster: destroyer 4 iterations, fighter jet 3, desert block 2, radar 2, soldier 3 across its lifetime, heli 3, frigate 2, most others converged in 1). An asset that has not converged after ~5 iterations is signaling a SYSTEMATIC defect — stop iterating deltas and hunt the pipeline.

### STEP 9 — LOG (the evidence pair + the verdict record)

Every iteration lands in the results artifact; every CLOSED defect lands in the DEBUG_LOG. The record per asset:
```
{ id, iterations: [ { n, artifactSha256, verdict, namedDeltas[], classification, fixCommit } ],
  finalVerdict: "PASS", evidencePair: { before: "<sha>", after: "<sha>" } }
```
The before/after evidence pair (pre-fix and post-fix extractions, both on disk, both sha'd) is the unit of proof that the loop WORKED — it is what makes the process auditable by a session that was not there. The drive's evidence lives in `evidence/previews/` and `.trident/container-test-results.json`.

## 2.1 The Canonical Shape (the loop as pseudocode)

```
expectation = from_spec(artifact)            # written BEFORE render
for iteration in 1..MAX:
    render(artifact, probe, camera_intent)   # STEP 1 — instrument, not hope
    png = extract_byte_exact(container_path) # STEP 2 — base64 → host decode
    assert magic(png) and len(png) == container_stat   # transport check
    image = multimodal_read(png)             # STEP 3 — independent reader
    verdict, deltas = rubric(image, expectation)       # STEPS 4-5 — named deltas
    if verdict == INCONCLUSIVE: fix_measurement(); continue
    if verdict == PASS: break
    cls = classify(delta, structure_check)   # STEP 6 — the decision tree
    fix_at_root(cls.owner_file)              # STEP 7 — never the symptom
    log(iteration, sha(png), deltas, cls)    # STEP 9 — every iteration
assert regression_sweep(all_other_assets)    # STEP 8 — zero broken windows
log_evidence_pair(before_sha, after_sha)     # STEP 9 — the proof unit
```

## 2.2 The Evidence Pattern (what makes a verdict auditable)

A verdict is auditable when a session that WAS NOT THERE can re-verify it. That requires four artifacts on disk:
1. **The before-extraction** (the failing render, sha'd) — proof the defect existed.
2. **The after-extraction** (the fixed render, sha'd) — proof the fix landed in pixels.
3. **The verdict record** (deltas + classification + iteration count) — the reasoning trail.
4. **The fix anchor** (file:line + commit) — the root-cause trail.

Anything less is a claim. The drive's per-asset ledger (EVIDENCE_STATE.md §roster) carries exactly these four for every asset, which is why an external reviewer (the Grok audit) could verify the build from the package alone — and why its findings (the soldier legs, the heli tail) were actionable line-items rather than vibes.

---

# PART 3 — THE VERDICT RUBRIC (how to LOOK)

## 3.1 The Five Questions (asked per artifact, against the written expectation)

1. **SILHOUETTE**: does the artifact read as its CLASS from the frame? (a destroyer reads as a warship; a soldier reads as a bipedal infantry figure; a dashboard reads as a dashboard). The silhouette is the first and coarsest semantic check — most catastrophic defects (wrong proportions, missing components, assembled-backwards geometry) fail here.
2. **MATERIALS**: are the surfaces believable UNDER THE ACTIVE PROBE? Baked albedo visible? Not washed to white, not crushed to black? The probe was chosen in Step 1 as the measurement instrument — a material verdict is always material-UNDER-PROBE.
3. **PROPORTIONS + RELATIONSHIPS**: are the components the right size relative to each other and connected where they should be? (deck within hull; rotor on mast; tail rotor at fin; legs parallel). This is where the drive's worst defects lived — structurally-valid, visually-wrong assemblies.
4. **FRAMING + COMPOSITION**: is the whole artifact in frame? Is anything cropped? Is the camera angle the intent (three-quarter hero for assets, spawn-distance for in-scene)? Cropping is an INCONCLUSIVE-grade measurement defect — judge the artifact only when the frame shows it.
5. **THE DELTA HUNT**: sweep the artifact hunting for anything not explained by the expectation. The hunt is ACTIVE — enumerate regions (top/bottom/left/right/center) and interrogate each. A passive glance is how a floating tail rotor survives three reviews.

## 3.2 The Named-Deltas Discipline

A named delta is: `<component> <wrong-relationship> <frame-location> [+ severity]`.
- GOOD: "tail rotor hub floats ~1.5 units off the fin leading edge, upper-left of frame, severe"
- GOOD: "deck plate proud of the hull sides by ~8% at the stern taper, minor"
- BANNED: "looks a bit off", "the legs area seems weird", "quality could be better"

Why the discipline is mechanical and not stylistic: the named delta is the INPUT to the classification tree (Step 6). "Legs crossed at mid-stride" classifies to PIPELINE (structure was at rest — the parse proved it) while "legs are bad geometry" would misclassify to SCRIPT and send the fix to the wrong file. The name determines the owner. An unnamed delta is an unfixable delta.

## 3.3 The Classification Decision Tree (owner-selection is the point)

Reproduced with the real drive examples per branch:

**SCRIPT DEFECT** (structure wrong → fix the generator):
- The frigate deck plate's width is AUTHORED geometry — an explicit-dims primitive in the shared warship script (templates-warships.ts:210); the overhang was drawn, not rendered-in. Fix: the x-scale constant.
- The tail rotor's seating is AUTHORED — the location tuple in templates-air.ts (the polish Y 0.14→0.12). Fix: the offset constant.
- Test: re-parse the artifact's structure after fix; the structure change must be visible in the mechanical check (node positions/transforms) AND the pixels.
- THE FABRICATION WARNING (learned the hard way while drafting this bible): do not invent rubric examples. Two drafted examples here ("mosque dome squat", "rifle stock detached") were DELETED because neither defect ever occurred — both assets converged in one iteration. A bible about evidence does not get fictional evidence; every example in a process document must trace to the record or be labeled ILLUSTRATIVE.

**PIPELINE DEFECT** (structure right, pixels lie → fix the wrapper):
- BUG-02 black frame: bound_box was LOCAL space; camera landed inside geometry. Fix: matrix_world the bbox. Detected as: render pure black + GLB parse showing valid geometry = structure-right/pixels-wrong.
- BUG-25 posed preview: GLB parse showed rest pose (structure right); preview showed mid-stride. The STRUCTURE-YES branch is what redirected the fix from the template (where the Grok audit's framing pointed) to the wrapper's stage ORDER — the fix that actually worked.
- BUG-26 detached rotors: the reset-exoneration (a byte-identical render with the suspected code removed) + the git-diff isolation proved the pipeline's rig_vehicle owned it; the stale matrix_world read was the root.
- BUG-03/04/05 washed renders: exposure constants in the probe definitions — three retunes, each verified by re-render.
- BUG-01: destroyer GLB chain rejected at the gate with equal-tris LODs — the gate's order rule was wrong, not the meshes.

**TRANSPORT DEFECT** (the evidence channel corrupted → fix the channel):
- A decode that produced a truncated PNG (byte count < container stat) — the verdict was INCONCLUSIVE and the CHANNEL was fixed (re-extract), never the asset judged.
- The S9 harness captured a blank page twice — both were transport/measurement failures (module load raced the capture; vite HMR websocket kept networkidle0 from settling), fixed in the harness, and the ASSET was never judged on those frames.

**ENVIRONMENT DEFECT** (engine absent → fix the setup):
- ENGINE_MISSING manifests name the install command (`npm i -g @gltf-transform/cli`, `pip install cadquery`). The render never happened — there is nothing to look at; the loop defers to the status table.

**THE TREE'S MOST IMPORTANT EDGE is structure-YES → pipeline.** Every one of the drive's worst defects (crossed legs, detached rotors, black frames) lived on that edge. It is also the edge structural tests are BLIND to by definition — the structure is right. That is the entire reason ViL exists.

## 3.4 Iteration Convergence + When to Stop Iterating Deltas

- Track iteration count per asset. Convergence = PASS with zero named deltas on a FRESH extraction.
- **The 5-iteration rule**: an asset still failing after ~5 iterations is not accumulating random deltas — a SYSTEMATIC defect is producing them. Stop delta-hunting; go one level up: re-derive the expectation (is the spec itself renderable?), re-verify the pipeline stage order, re-check the probe. (The destroyer needed 4 — the 4th converged only after the gate floor was understood as systematic, not per-delta.)
- **The regression sweep after EVERY fix**: `fix A → verify A → verify all prior PASSes`. The closeout's BUG-26 fix touched the shared rig path — soldier and frigate were re-verified not because they changed but because the PIPELINE changed. Zero broken windows applies to pixels.

---

# PART 4 — THE EVIDENCE PIPELINE (exact commands, E2E)

## 4.1 The Container→Host Channel (the proven path)

Docker cp is firewall-blocked in the house tooling. The ONLY working path is exec-stdout base64 → host tool-output file → decode. (The channel GENERALIZES: any environment where you can execute a command inside the build context and capture stdout byte-exact on the verifier's side — ssh+base64, kubectl exec, CI artifact upload — satisfies the same law. The house specifics below are the proven instance; the law is the invariant.) Verbatim sequence:

```
# 1. inside the container — the artifact list + the stat (the byte-count ruler):
exec: ls -la /tmp/omni-canvas/<workspace>/

# 2. the extraction (minimal params! containerName + the command only):
exec: base64 -w0 /tmp/omni-canvas/<workspace>/<artifact>.png
#     → display truncates; the COMPLETE base64 is in the HOST tool-output file:
#       ~/.local/share/opencode/tool-output/tool_<id>

# 3. the host-side decode + the three checks:
python3 -c "
import json, base64
d = json.load(open('<tool-output-file>'))
out = d.get('stdout') or ''
if isinstance(out, dict): out = out.get('stdout','')
data = base64.b64decode(out.strip())
open('<dest>','wb').write(data)
print('bytes:', len(data), 'magic:', data[:4])
"
# 4. the byte-count check: len(data) MUST equal the container-side stat size.
#    magic: PNG b'\x89PNG' · GLB b'glTF'
```

THE TRUNCATION TRAP: the exec tool DISPLAY may show "...N bytes truncated..." — that is the DISPLAY, not the payload. The file has everything. Never re-extract because the display truncated; verify by the byte count. Conversely, a decode whose byte count does NOT match the container stat is a TRANSPORT defect — re-extract, never judge.

## 4.2 The Multimodal Read

The house workhorse is the native read of the decoded PNG — the image enters the agent context as an attachment and the rubric (Part 3) is applied against the written expectation. Discipline:
- Read the NEW extraction each iteration (never a memory of the prior frame).
- The read happens AFTER the byte/magic checks — you are interpreting a proven-intact artifact.
- Record the verdict + deltas IMMEDIATELY (they go to the results artifact; a delta not logged is a delta that did not happen).

## 4.3 Omni-Vision Modes (when to use the tool instead of the native read)

- **direct mode** (`omni_vision(file_path, mode="direct")`): single images or batch frames; reads into context. Use for multi-frame sweeps (video keyframes, PDF pages) or when a structured second opinion is wanted alongside the native read.
- **api mode** (the shadow-enhanced form — REQUIRES `media_context` 500+ chars, `analysis_goal` 200+ chars, `output_requirements` 3+ items): the backend silently injects storyline + prior-frame context and returns a grounded verdict. Use for PIPELINE-GRADE verification where the verdict must be reproducible and the read must be constructed from the artifact rather than the generation session. This is the form to embed in automated loops (the brainforge/omni-canvas tool verification stages).
- The bare `prompt` arg is REJECTED in api mode — the context args are the quality gate.

## 4.4 The Browser Channel (UI/dashboards — the S9 pattern)

Rendered UI cannot be extracted from a container filesystem — it must be CAPTURED from a real browser:
1. Serve the app (vite dev / built bundle + static server).
2. Drive a real (headless or headed) chromium: the house pattern is puppeteer with `--no-sandbox --disable-gpu --enable-unsafe-swiftshader` for software WebGL.
3. WAIT FOR THE APP'S OWN READINESS SIGNAL, not a timer: `page.waitForFunction('window.__READY_FLAG')` — the drive's S9 harness exposed `window.__S9_READY = {loaded, total, lines}`. Timers race module loads; two blank captures were taken before the readiness-signal discipline landed.
4. `waitUntil: 'domcontentloaded'` + the readiness signal — `networkidle0` NEVER SETTLES on vite dev (the HMR websocket is a permanent connection). This cost a 90s timeout to learn.
5. Screenshot → PNG → the SAME Grade-1 checks (bytes, magic) → the SAME multimodal read.
6. Surface `pageerror` + console errors into the verdict record — a page that renders but throws is FAIL, not PASS.

## 4.5 The TUI-Result Channel (verifying the tool's OWN report)

The container TUI screenshot (via the container-testing tool's screenshot action) verifies the TOOL RESULT text — the status line, the artifact list, the ANIM count, the failures array. This is a THIRD channel with a distinct role: it verifies what the pipeline CLAIMED, while the extracted PNG verifies what the pipeline PRODUCED. Both are logged. A TUI claim contradicted by the extracted artifact is a FINDING (the pipeline's reporting is defective) — in the drive, the TUI status text and the on-disk artifacts agreed every time, which is itself evidence the reporting layer is sound.

## 4.6 The GLB Mechanical Cross-Check (visual verdict + structural confirmation = EXTRACTED)

For 3D assets, the visual verdict is CONFIRMED — not replaced — by parsing the GLB's JSON chunk. The soldier case is the canon:

```
python3: parse glb header (12-byte header; chunk len/type at 12:20) → json.loads(glb[20:20+clen])
  print animations: ['aim','idle','walk']        ← ANIM:3 confirmed
  print skins: 1                                  ← skinning confirmed
  for leg/arm nodes: print rotation quaternions
  → upper_leg.L/R BOTH [1, 0, -4.37e-08, 0]      ← symmetric REST (the 180° X rest-roll),
                                                    NOT an asymmetric ±0.55 rad walk pose
```

The discipline: **the eyes make the verdict; the parse makes it EXTRACTED.** The preview showed parallel legs (Grade 3) and the transforms proved the bind pose (Grade 2 agreeing) — together the verdict is a fact about the artifact, not an opinion about an image. When eyes and parse DISAGREE, that disagreement is itself the finding (it exposed the dead `Pose.position` code — see BUG-18/25, Part 5).

## 4.7 Evidence Hygiene (the record)

Per verified artifact, the results artifact carries: artifact path + sha256 + byte count; extraction channel + tool-output file id; the verdict token; the named deltas; the classification; the fix commit; the evidence-pair shas (before/after). The pair lives in the repo (`evidence/previews/` in the drive) — committed, named for what they prove (`soldier_parallel_legs.png`, `frigate_deck_in_hull.png`, `heli_rotors_seated.png`). A name that states the PROVEN EXPECTATION turns the evidence folder into a self-describing verification ledger.

---

# PART 5 — THE BUG LEDGER (what the loop caught — the proof of the pattern)

Every entry: the VISUAL symptom → the loop step that caught it → the root cause → the fix → the re-render proof. This ledger is the bible's evidence that the pattern works: not one of these defects was caught by a unit test, a typecheck, or a pixel histogram. All of them shipped in renders that were LOOKED at.

## 5.1 BUG-01 — the gate rejected valid LODs (destroyer, 4 iterations)
- VISUAL SYMPTOM: none at first — the PIPELINE refused to emit the destroyer GLB chain. The loop's role: the previews across 4 iterations kept showing correct geometry while the gate failed the chain, which isolated the defect to the GATE's rule, not the meshes.
- ROOT CAUSE: the LOD-order gate rejected equal-tris LODs; tiny meshes sometimes cannot simplify further — equal tris IS the floor, not an error.
- FIX: gate_lod_order floor rule (commit d3c67b0).
- RE-RENDER PROOF: destroyer converged PASS at iteration 4; chain emitted 3 LODs + registry.

## 5.2 BUG-02 — the black frame (building_desert_block)
- VISUAL SYMPTOM: the preview was PURE BLACK. First verdict: INCONCLUSIVE (measurement defect — nothing to judge).
- CLASSIFICATION: the GLB side showed valid geometry → structure-right/pixels-wrong → PIPELINE. The camera.
- ROOT CAUSE: the camera fit used the LOCAL bounding box; the artifact sat far from the origin, so the camera landed inside the mesh.
- FIX: fit from the WORLD-space bbox (matrix_world), ground-planes excluded from the fit.
- RE-RENDER PROOF: block v2 showed the full block, lit, in frame — PASS.

## 5.3 BUG-03/04/05 — the washed probes (three rounds)
- VISUAL SYMPTOM: renders blown out to white (overcast probe at 2.5/2.2) or blasted (desert_sun at 6.0/1.2/1.4) across whole frames.
- CLASSIFICATION: every material affected uniformly, structure fine → PIPELINE (probe exposure).
- FIX: overcast to 3.0-tight/0.45-sky-blue; desert_sun to 2.6/0.5/0.4; sky-blue world backdrop for preview depth (BUG-05).
- LESSON: the probe is the measurement instrument — a washed render is an INCONCLUSIVE measurement, and the fix is instrument calibration, never asset surgery. The values are SETTLED: re-tuning without a washed-out preview in hand is scope creep.

## 5.4 BUG-20 — the frigate deck overhang
- VISUAL SYMPTOM: the deck plate extended past the hull sides at the stern taper.
- CLASSIFICATION: the deck's width is AUTHORED geometry — an explicit-dims primitive in the shared warship script (a render cannot widen an authored plate) → SCRIPT. (Note the honest rationale: no GLB position-parse was run for this one — the authored-geometry argument alone routes to SCRIPT with certainty, because a pipeline defect cannot change what the script explicitly draws.)
- FIX: deck x-scale `HW * 1.70 → HW * 0.96` (templates-warships.ts:210) — shared by both warships via the common script (the destroyer had the same overhang; one fix, both verified).
- RE-RENDER PROOF: `frigate_deck_in_hull.png` — deck inside the hull silhouette, stern flush. NOTE: this defect passed EVERY unit test and pixel check across multiple builds before the loop's verdict named it.

## 5.5 BUG-21/26 — the detached helicopter tail rotor (the two-stage diagnosis)
- VISUAL SYMPTOM (v4.1 roster): tail rotor read as a separate object near the fin; logged as a "framing artifact" — an UNDER-diagnosis the loop's own record enabled by under-naming the delta.
- VISUAL SYMPTOM (closeout v1): tail rotor FAR off the fin, up-left in the sky; main rotor floating ~2u above the mast. This time the deltas were NAMED with magnitudes and directions, which is what allowed the mechanical follow-ups.
- THE EXONERATION STEP: a suspected fix (the render-pose reset) produced a BYTE-IDENTICAL render (same 1,141,918 bytes) — proof the suspected mechanism was not the cause. Byte-identical re-renders are the loop's cheapest and most decisive experiments: same bytes = the change did nothing.
- THE ISOLATION STEP: `git diff` of the template showed only the 3-site Y edit (innocent — 0.02 units cannot fly a rotor into the sky) → the defect PREDATED the polish; the owner was the rig.
- ROOT CAUSE: `rig_vehicle()` read `empty.matrix_world.inverted()` immediately after assigning `empty.location` — Blender's matrix_world is STALE (identity) until a depsgraph update. matrix_parent_inverse = identity ⇒ every rotor displaced by its OWN position vector. Main rotor at (0.2,0,2.05) → rendered ~(0.4,0,4.1). Tail rotor at (-3.7,0.12,2.05) → ~(-7.4,0.24,4.1). The named deltas' directions and magnitudes MATCHED the arithmetic — the visual verdict and the math confirmed each other.
- FIX: `bpy.context.view_layer.update()` before the matrix read (one line).
- RE-RENDER PROOF: `heli_rotors_seated.png` — main rotor ON the mast, tail rotor AT the fin. GLB re-parse: ANIM:2 [spin, spin.001] intact.
- THE META-LESSON: the first under-named delta ("reads detached — framing artifact") let a real shipped defect masquerade as cosmetics for a full session. Name deltas with magnitudes and directions; magnitudes arithmetic-check against root causes.

## 5.6 BUG-18/25 — the crossed-legs soldier (the loop's crown jewel — three renders, three discriminators)
- VISUAL SYMPTOM (roster build): soldier preview showed legs crossed in an X, mid-stride.
- THE GROK AUDIT's framing pointed at the geometry template. The closeout loop REFUTED that framing mechanically:
  - v1 render: legs crossed. GLB PARSE: node transforms at symmetric REST quaternions `[1,0,-4.37e-08,0]`, ANIM:3, skins 1 — the EXPORTED ASSET WAS FINE. The structure-YES branch: the pixels lied about correct structure → PIPELINE.
  - v2 render (with the "REST-pose fix" deployed): STILL crossed — and the fix was then PROVEN DEAD CODE: an in-container probe (`hasattr(o.pose,'position')` → False) showed `Pose.position` does not exist in Blender 4.2; the assignment had been throwing AttributeError into a swallowed catch since its commit. TWO discriminators in one iteration: the re-render (unchanged) AND the API probe.
  - v3 render (real fix — zero the pose bones + unassign the action before render): PARALLEL LEGS. Cross-confirmed by GLB parse (rest transforms intact, ANIM:3 intact — the export path untouched).
- THE CHAIN OF LESSONS: (1) the preview lies differently than the export lies — ALWAYS parse the structure before classifying a visual delta; (2) a swallowed exception converts a missing API into phantom confidence — the "fixed" defect was never fixed; (3) the fix that finally worked was found BY the loop's discrimination, not by the original audit's plausible-but-wrong framing.

## 5.7 The Roster Iteration Table (the loop's yield, per asset)

| Asset | Iterations to converge | What the loop caught |
|---|---|---|
| warship_destroyer | 4 | gate floor (BUG-01) |
| warship_frigate | 2 | deck overhang (BUG-20) |
| fighter_jet | 3 | framing + sky backdrop |
| attack_helicopter | 3 (closeout) | detached rotors (BUG-26) + the exoneration discipline |
| mbt_tank | 1 | — (bake verified on first render) |
| infantry_soldier | 3 (closeout) | crossed legs → dead-code discovery (BUG-18/25) |
| assault_rifle | 1 | — |
| building_desert_block | 2 | black frame (BUG-02) |
| building_mosque_dome | 1 | — |
| radar_station | 2 | cropped framing |
| fuel_depot_tank | 1 | — (richest bake verified) |

Yield: 23 tracked loop iterations across 11 assets, 10+ real defects, 8 permanent pipeline fixes, 2 script fixes. Zero of them findable by Grade-1/Grade-2 checks alone. THE LOOP IS THE QUALITY ENGINE.

## 5.8 S9 — the browser-scene proof (the loop generalized beyond files)
The bridge's GLBs were NullEngine-tested (structural) but never SEEN in a live scene. The S9 harness (vite + puppeteer) closed it — and the loop's transport discipline carried: two blank captures (measurement races) were correctly diagnosed as INCONCLUSIVE transport defects (module-load race; networkidle0-vs-HMR-websocket) before the readiness-signal discipline landed; the final capture (92,148B, non-blank) was READ: soldier standing with rifle, tank with baked camo, heli in frame — 3/3 heroes. The visual verdict is what converted "the loader's unit tests pass" into "the game renders the assets."

---

# PART 6 — THE ANTI-PATTERNS (the bullshit catalog)

Each: the pattern, the root cause, the failure it causes, the countermeasure law. These are the ways verification gets faked — by the tool, by the agent, by the process.

## AP-1 — IMAGE-ONLY VERIFICATION (the histogram lie)
Pattern: asserting correctness from image statistics — pixel std-dev, color count, entropy, file size.
Root cause: Grade-1 signals are cheap and automatable, so they get promoted to verdicts.
Failure: every drive defect passed pixel checks. The deck overhang had a healthy histogram. Crossed legs have rich color entropy. A non-blank wrong image is MORE non-blank than a blank right one.
COUNTERMEASURE LAW: pixel-std gates BLANK, never WRONG. Grade-1 is a transport precondition for the read, never a verdict. (The house manifests record `NON_BLANK std=` as a SMOKE result — smoke, not verification.)

## AP-2 — APPROVE-BY-DEFAULT (the founding sin)
Pattern: a critique layer that returns "approved" when it could not judge — no VLM client, empty reference, missing deltas.
Root cause: designing the happy path first; a refusal feels like a failure state instead of the honest one.
Failure: the v3 incident — 221 blank charts shipped as APPROVED_WITH_WARNINGS.
COUNTERMEASURE LAW: the verdict enum is exactly PASS | FAIL | INCONCLUSIVE; no-client and cannot-judge are INCONCLUSIVE, never PASS; the no-client state is a TESTED contract (the vil-verdicts suite asserts APPROVED_WITH_WARNINGS is ABSENT).

## AP-3 — THE BLIND BUILD
Pattern: rendering artifacts and shipping them without ever extracting/looking — "the pipeline ran, exit 0."
Root cause: pipeline-completion bias; the exit code FEELS like the product.
Failure: every defect in Part 5 shipped blind first. The roster's first container run would have shipped crossed legs, detached rotors, and the deck overhang to the game.
COUNTERMEASURE LAW: an artifact type is DONE only when its verification loop has run; "built" and "verified" are different words with different meanings and the second requires the PNG on disk plus the verdict in the record.

## AP-4 — THE STALE PREVIEW
Pattern: verifying against a render made before the last code change; comparing from memory of the previous image.
Root cause: extraction is friction; memory is free.
Failure: the fix looks applied; the pixels are from the old build. The closeout's v2→v3 soldier verdicts were only trustworthy because each was a NEW extraction (byte counts differed: 1,182,767 → 1,182,741 → 1,172,934).
COUNTERMEASURE LAW: every verdict consumes a FRESH extraction; record the extraction's sha + byte count WITH the verdict; byte-identical artifacts across a code change are themselves a FINDING (the change did nothing — see 5.5's exoneration).

## AP-5 — THE TRUNCATED-EXTRACTION TRUST
Pattern: judging from the display-truncated transcript, or assuming the base64 in the visible output is the payload.
Root cause: the transcript LOOKS complete.
Failure: judging a corrupt/partial decode; or wastefully re-extracting a complete payload because the display truncated.
COUNTERMEASURE LAW: the verdict consumes the DECODED HOST FILE; the three checks (byte count vs container stat, magic, sha) run before any read. Display truncation is cosmetic — documented, tested, and handled.

## AP-6 — THE CONFORMANCE VERDICT (M5 in visual form)
Pattern: seeing what the context expects — the caller says "the soldier is fixed," and the reader confirms legs that are still crossed.
Root cause: the reader shares context with the expectation-setter; belief frames perception.
Failure: the original crossed-legs diagnosis nearly fixed the TEMPLATE (the wrong file) because the audit's framing said geometry.
COUNTERMEASURE LAW: the reader's ruler is the WRITTEN expectation from the spec (Step 1), never the session's beliefs; the mechanical cross-check (Part 4.6) is the tiebreaker — when the parse and the expectation agree against the impression, the impression is wrong. THE BRIEF'S FRAMING IS THE BEHAVIOR applies to eyes too.

## AP-7 — THE STRUCTURAL PASS
Pattern: "the GLB parses, the schema validates, the tests pass — therefore it's correct."
Root cause: Grade-2 exhausts what non-visual tooling can see, so non-visual tooling declares victory at its own horizon.
Failure: crossed legs in a schema-valid GLB. Detached rotors in an animation-valid GLB.
COUNTERMEASURE LAW: structural correctness is a PREMISE for the visual verdict, not a substitute for it. The two-confirmation discipline (eyes + parse) is the standard for shipped 3D assets.

## AP-8 — THE SINGLE-FRAME VERIFICATION
Pattern: one render, one angle, one state — PASS.
Root cause: one frame is cheap; a sweep is work.
Failure: the heli's detachment was angle-dependent (the auto-fit camera exaggerated it); a state-dependent defect (a walk-cycle glitch) hides in the rest frame.
COUNTERMEASURE LAW: adversarial framing — verify from the angles and states where defects HIDE (close crop on the delta region, alternate camera, the animated state at multiple keyframes) when the artifact class carries such risk. The drive's previews were single-hero-frame by design (asset proof), but every DELTA hunt was frame-region-enumerated, and state-carrying assets (ANIM clips) got parse-level state checks.

## AP-9 — THE UNVERIFIED REGENERATION
Pattern: applying a fix, re-rendering, and shipping WITHOUT re-inspecting ("the fix is obviously right").
Root cause: fix-confidence transfer — the certainty about the edit masquerades as certainty about the pixels.
Failure: BUG-25's v2: the "fixed" bundle rendered IDENTICALLY crossed legs — the re-inspection was what exposed the dead code. Skipping it ships the lie.
COUNTERMEASURE LAW: a fix is not a fix until the pixels say so (Step 8). The re-inspection consumes a fresh extraction with a new sha.

## AP-10 — THE SELF-GRADING LOOP
Pattern: the generation context grading its own render ("I rendered the soldier and I can see the legs are now parallel" — from the same context, without a new extraction).
Root cause: convenience; the reader is already in the session.
Failure: conformance (AP-6) at generator strength — the context that WROTE the defect cannot be trusted to SEE it.
COUNTERMEASURE LAW: the INDEPENDENT-READER LAW (1.5 Law 2). Acceptable: a fresh multimodal read of the decoded file by the agent (new attachment, new analysis). Better for pipelines: omni-vision api mode whose context is built from the artifact. Best: a second model/VLM with no shared context.

## AP-11 — THE PROSE VERDICT
Pattern: "it works", "verified", "looks great" — with no PNG on disk, no sha, no deltas.
Root cause: prose is cheaper than evidence.
Failure: unauditable claims; the next session inherits a lie.
COUNTERMEASURE LAW: evidence on disk or it did not happen (the house's Evidence Law, applied to vision). The verdict record format (Part 7.4) is the minimum.

## AP-12 — THE CHANNEL-CONFUSION ERROR
Pattern: verifying the wrong artifact for the question — a TUI screenshot of the tool's status line offered as proof the RENDER is correct; a thumbnail of a preview offered as proof of texture quality; the HTML source offered as proof of the rendered page.
Root cause: channels look similar in a transcript (all are "images/text about the artifact").
Failure: the claim and the evidence are about different objects.
COUNTERMEASURE LAW: three channels, three questions — TUI frames verify what the pipeline CLAIMED (status text); extracted files verify what the pipeline PRODUCED (the pixels); browser captures verify the LIVE RUNTIME state. Match the channel to the question; log which channel each verdict consumed.

---

# PART 7 — THE TESTING DISCIPLINE (the loop itself is tested)

## 7.1 The Zero-Hint Visual Battery

The verification loop is CODE + PROCESS, and both are tested adversarially. The mandatory battery (run against any new ViL implementation — a tool, a harness, a pipeline stage):
1. **THE PLANTED DEFECT**: a deliberate visual defect is introduced into a known-good artifact (a part offset by 0.3 units; a material swapped to flat white). The loop MUST catch it with a named delta, unprimed. If the loop passes a planted defect, the loop is theater.
2. **THE CLEAN CONTROL**: the unmodified artifact must verdict PASS with zero deltas — a loop that finds defects in perfect artifacts is over-firing (the over-fire storm drowns real signals).
3. **THE DEAD-CHANNEL**: feed the loop a corrupt/truncated extraction. The required behavior: the three checks fail FIRST (byte count / magic) and the verdict is INCONCLUSIVE-transport — never a read of garbage.
4. **THE UNJUDGEABLE RENDER**: feed an all-black and an all-white frame. Required: INCONCLUSIVE (measurement), never PASS/FAIL — judging unjudgeable frames is fabrication.
5. **THE MUTATION CHECK**: for every automated visual assertion, invert the artifact and confirm the assertion FLIPS. A visual test that cannot fail is not a test.

## 7.2 The Mutation Check (applied to the rubric itself)

Each rubric question must be falsifiable: name a mutation to the artifact that would flip the answer. SILHOUETTE: swap two components → fails. MATERIALS: strip the bake → fails. PROPORTIONS: 2x one part → fails. FRAMING: translate the artifact 50% out of frame → fails. A rubric question with no falsifying mutation is decoration — delete it or sharpen it.

## 7.3 The ViL Tool Contract (vil-critique — the automated form)

The automated ViL layer (omni-canvas `vil-critique.ts`) is the pipeline-embedded form of the loop:
- **Inputs**: the rendered artifact + an optional reference image + the runtime VLM client.
- **Verdict enum**: `PASS | FAIL | INCONCLUSIVE` — plus named deltas on FAIL.
- **THE NO-CLIENT LAW**: no VLM client → `INCONCLUSIVE` — NEVER an approval. Tested explicitly: the suite asserts `APPROVED_WITH_WARNINGS` is ABSENT from the no-client output. (This is the scar tissue of the v3 incident, enforced by test.)
- **The honest gap**: the suite runs with MOCK clients; real-VLM critique quality is unmeasured until a run against a real reference. Document the gap; do not claim the mock battery proves real-VLM judgment.
- **The composition rule**: the automated ViL is the PIPELINE's gate; the session's native multimodal read is the ENGINEER'S gate. Both consume fresh extractions; neither replaces the other.

## 7.4 The Results-Artifact Schema (the verdict record)

```json
{
  "runId": "N1-RESTPOSE-POLISH",
  "container": "shark-oc-v41-n1",
  "deployedBundleSha256": "91f4171c...",
  "scenarios": [
    {
      "id": "N1-A-soldier-restpose",
      "verdict": "PASS",
      "passTokenMatch": true,
      "passToken": "ANIM:3 + _master.png + legs PARALLEL (visual)",
      "failTokenAbsent": true,
      "toolResultContext": "TUI result: status success, ANIM:3 (aim/idle/walk 36ch);
                            extracted preview read visually: legs parallel;
                            GLB parsed: skins 1, rest quaternions symmetric",
      "extraction": { "path": "/tmp/opencode/n1_soldier_v3.png",
                      "bytes": 1172934, "magic": "89504e47", "sha256": "..." },
      "channel": "extracted-file + TUI-frame + GLB-parse",
      "timedOut": false
    }
  ],
  "overallVerdict": "PASS"
}
```
Rules: every scenario names its CHANNEL(s) (AP-12); passTokens are TOOL-RESULT strings, never agent prose; the extraction block is the Grade-1 record; the visual verdict language names the deltas or declares zero-after-hunt.

---

# PART 8 — THE REPLICATION RECIPE (a new artifact type, E2E)

Given a NEW visual artifact class (a new renderer, a new 3D pipeline, a dashboard framework), produce its verified loop:

1. **Write the expectation** — from the SPEC, the named list of what a correct artifact shows. (No expectation, no verdict.)
2. **Pick the probe/environment** — the measurement instrument (lighting rig, viewport, browser size). Calibrate ONCE with a known-good reference; then frozen.
3. **Wire the extraction channel** — where does the artifact live? Container FS → base64 channel (§4.1). Browser → readiness-signal capture (§4.4). TUI → screenshot action (§4.5). Establish the three checks (bytes/magic/sha) on the FIRST extraction, before any verdict exists.
4. **Choose the reader(s)** — native multimodal read for engineering iterations; omni-vision api mode for pipeline-embedded verdicts; add the mechanical cross-check for structured formats (GLB parse, DOM query, JSON schema) so verdicts become EXTRACTED.
5. **Run the zero-hint battery** (Part 7.1) on the loop itself — planted defect, clean control, dead channel, unjudgeable frames, mutation checks.
6. **Operate the loop** (Part 2) — iterate to PASS-with-zero-deltas; count iterations; sweep for regressions after every fix.
7. **Log the ledger** — results artifact per §7.4; evidence pairs committed with names that state the proven expectation.
8. **Review the loop's own yield** — an artifact class whose loop finds nothing across builds is either perfect (rare) or under-probed (common). Tighten the rubric; add adversarial framing.

## 8.1 The Minimal Viable Loop (copy-paste skeleton)

```
EXPECTATION="soldier standing, legs parallel, rifle held, helmet on"   # from spec
render --probe desert_sun --rig soldier --out /tmp/omni-canvas/<ws>/   # STEP 1
exec: ls -la /tmp/omni-canvas/<ws>/                                    # STEP 2a — the ruler
exec: base64 -w0 /tmp/omni-canvas/<ws>/<artifact>.png                  # STEP 2b
python3 decode(host_tool_output_file) → dest.png                       # STEP 2c
assert bytes == ruler and magic == PNG                                 # STEP 2d
read dest.png (multimodal, fresh)                                      # STEP 3
verdict, deltas = rubric(image, EXPECTATION)                           # STEPS 4-5
if INCONCLUSIVE: fix the measurement (probe/framing/channel); goto render
if FAIL: classify(delta_tree) → fix at root → git commit → goto render # STEPS 6-8
log(verdict, deltas, sha, iteration)                                   # STEP 9
```

---

# PART 9 — THE IRON LAWS

1. **A preview not looked at is an unverified asset.**
2. **Pixel-std gates BLANK, never WRONG.** Grade-1 is a precondition, never a verdict.
3. **The reader is independent of the generator.** Same-context self-grading is invalid.
4. **The verdict consumes a FRESH extraction** — new sha, new decode, every time.
5. **Byte count + magic before any read.** Never interpret an unverified-transport artifact.
6. **Deltas are NAMED** — component, relationship, frame-location, magnitude. "Looks off" is banned.
7. **Every delta is CLASSIFIED** — script / pipeline / transport / environment — before any fix.
8. **Fixes go to the tree's owner file.** A fix that cannot name its owner file is misclassified.
9. **A fix is not a fix until the pixels say so** — fresh extraction, fresh read, new sha.
10. **Every fix gets a regression sweep** — the pipeline changed, so everything upstream of the change is re-verified.
11. **INCONCLUSIVE is a first-class verdict** — judging an unjudgeable render is fabrication; refusing to judge is honesty.
12. **No-client means INCONCLUSIVE, never approve.** The approve-by-default contract is banned forever.
13. **Verdicts are logged with their evidence pairs** — before/after, sha'd, committed, named for what they prove.
14. **Eyes make the verdict; structure makes it EXTRACTED.** For structured formats, the parse confirms the read.
15. **Byte-identical re-renders are findings** — the change did nothing; hunt the mechanism, not the delta.
16. **The 5-iteration rule**: repeated deltas mean a systematic defect — escalate to the pipeline/spec level.
17. **Match the channel to the question** — TUI frames verify claims; extracted files verify pixels; browser captures verify the live runtime.
18. **Adversarial framing beats hero framing** — hunt where defects hide: the delta region close-up, the animated state, the alternate angle.
19. **The loop is code and is tested like code** — planted defects, clean controls, dead channels, mutation checks.
20. **The expectation comes from the SPEC, written before the render** — a verdict without a pre-written ruler is conformance waiting to happen.

---

# PART 10 — CANON INTEGRATION

- **With the Runtime-Grade Test Law**: the container test IS the test — and the ViL loop is the part of the container test that verifies MEANING. The results artifact's per-scenario records (§7.4) are the container-test-results format; passTokens are the tool-result strings; the visual verdict rides beside them. A container test without a looked-at artifact is a structural pass wearing a runtime costume.
- **With the Shadow-Enhanced Tools Bible**: omni-vision api mode IS a shadow-enhanced perception tool (R1 — the original reference). The media_context/analysis_goal floors are the validation stage; the storyline injection is the memory; the verdict is the verified output. The no-approve-without-client law is the loud-fail law in judgment form.
- **With the ISE/Lexicon law**: the classification tree is a DETECTOR→DECISION separation — the named delta is detected evidence; the owner-file routing is the decision; the {delta, classification, fix-commit} record is the triplet. INCONCLUSIVE is the fail-state (never a fabricated PASS).
- **With the CUSTOM_EVENT_HOOK bible**: the extraction channel (§4) is the observation plane applied to rendered artifacts — the tool-output file is the event store; the decode+checks are the reader; the evidence pair is the before/after capture.

**Canon status**: AUTHORITATIVE for any build producing visual artifacts. The v4.1 drive + closeout is the reference implementation; the evidence lives in `Active_Projects/Omni_Canvas_Tool/evidence/` (and the sealed v4.1 ship package) — the before/after pairs are committed and named.

---

# PART 11 — THE QUICK-REFERENCE CARD

```
RENDER   : probe chosen · camera intent · EXPECTATION WRITTEN FROM SPEC
EXTRACT  : exec base64 -w0 → host tool-output file → decode
CHECK    : bytes == container stat · magic == PNG/GLB · sha recorded
LOOK     : fresh multimodal read · rubric: silhouette/materials/proportions/
           framing/delta-hunt
VERDICT  : PASS (zero deltas after a real hunt)
         · FAIL (named deltas: component+relationship+location+magnitude)
         · INCONCLUSIVE (measurement defect → fix probe/framing/channel first)
CLASSIFY : structure wrong→SCRIPT · structure right/pixels wrong→PIPELINE ·
           bytes wrong→TRANSPORT · engine missing→ENVIRONMENT
FIX      : at the tree's owner file · never the symptom · commit
RE-RENDER: fresh extraction · fresh read · new sha · byte-identical = finding
SWEEP    : regression-verify all prior PASSes touched by the pipeline change
LOG      : verdict + deltas + classification + fix commit + evidence pair
NEVER    : pixel-std as verdict · approve-by-default · blind builds · stale
           previews · self-grading · prose verdicts · structural PASS as proof
```

**END OF BIBLE.**

---

# PART 2A — DEEP-DIVE: THE SOLDIER CASE, E2E (the loop narrated against the real session)

This is the full closeout N-1 soldier verification, every step, with the real values. It is the reference execution of Part 2 — a fresh session can replicate the entire process from this narrative alone.

## 2A.1 The expectation (Step 1, written before the render)
From the spec + the Grok audit finding: "the rigged soldier stands at REST — legs parallel, feet planted at z=0, arms at the sides, helmet on, fatigues/vest/boot materials distinct under desert_sun, holding nothing at attention. ANIM:3 clips (aim/idle/walk) ride in the GLB but MUST NOT pose the mesh." The last sentence is the ruler that decided everything: the PREVIEW must show the bind pose.

## 2A.2 Render v1 (the roster bundle, 807a50c9 — the "REST-pose fix" deployed)
Container: shark-oc-v41-n1, Muse Spark 1.2 Free (OpenCode Zen) driving the plugin TUI. The prompt pattern (send-keys -l): "Read the file /tmp/sg/sg_infantry_soldier.json and run the omni canvas tool in api mode passing its JSON content as the scene graph exactly verbatim. Then report status, artifacts, ANIM count."
Result: status success; artifacts incl. infantry_soldier_asset.glb (122,188B) + preview (1,182,767B); TUI reports ANIM:3.

## 2A.3 Extract v1 (Steps 2, exact channel)
```
exec: base64 -w0 /tmp/omni-canvas/infantry_soldier/infantry_soldier_master.png
→ tool_036f584aa001o2IppKm3EQfJio (host)
decode → /tmp/opencode/n1_soldier_master.png
bytes: 1182767  magic: b'\x89PNG'   ✓ transport clean
```

## 2A.4 Read v1 (Step 3) + Verdict (Steps 4-5)
Multimodal read. Named deltas: "left and right legs cross in an X pattern at mid-stride; arms swung asymmetrically; boots offset — the mesh is posed at a walk frame, not at attention." VERDICT: FAIL. The written expectation (bind pose) vs the pixels (mid-stride) — the delta is precise, and its PRECISION is what armed the next step.

## 2A.5 The structural cross-check (Part 4.6 — before classifying)
Parse the GLB JSON chunk: animations [aim, idle, walk] (ANIM:3 ✓), skins: 1 ✓, and the limb nodes:
```
upper_leg.L rot: [1, 0, -4.371138828673793e-08, 0]   ← the 180° X rest-roll
upper_leg.R rot: [1, 0, -4.371138828673793e-08, 0]   ← IDENTICAL (symmetric)
lower_leg.L/R rot: None (identity)
```
Symmetric rest transforms — a mid-stride pose would be ASYMMETRIC (±0.55 rad counter-phase). STRUCTURE IS RIGHT. Classification: PIPELINE. The pixels misrepresent correct structure.

## 2A.6 Fix v1 — and the v2 discriminator (Step 8's mutation)
The deployed fix (`pose.position='REST'` before export) re-deployed as bundle 7b6387fa. Fresh setup, fresh render, fresh extraction: bytes 1,182,741 (DIFFERENT — a new render, transport clean). Read: STILL crossed.
THE DISCRIMINATOR CHAIN: new render + same visual = the fix did nothing. Then the API probe:
```
blender --background --python-expr "…; print('HAS:', hasattr(o.pose,'position'))…"
→ HAS: False
→ SET_FAIL 'NoneType' object has no attribute 'position'
```
`Pose.position` DOES NOT EXIST in Blender 4.2. The committed "fix" had been a swallowed AttributeError since commit 130117c. Two mechanical discriminators (fresh-render delta + API probe) killed the phantom fix in one iteration. THE GLB WAS ALWAYS CLEAN — the exporter writes bone REST matrices as node TRS; only the PREVIEW was posed, because the rig's keyframe_insert leaves rotations on the pose bones and the rig runs BEFORE the render.

## 2A.7 The real fix + v3 (the convergence)
`reset_pose_for_render()`: for every armature — animation_data.action = None, zero every pose-bone rotation_euler, frame_set(1); called BEFORE render only (export untouched — its ANIM:3 output was proven correct and unassigning at export could drop the active clip). Rebuilt as bundle **916457ea** (the BUG-25 real-fix build), fresh setup, fresh render.
Extraction v3: bytes 1,172,934 — new render. Read: **legs PARALLEL, feet planted, arms at sides, helmet on, materials distinct** — PASS, zero deltas after the hunt. GLB re-parse cross-check: 121,656B (post-optimize), ANIM:3 36-channels-each, skins 1, rest quaternions intact — the export path unharmed.
Evidence pair: n1_soldier_master.png (FAIL, crossed) ↔ n1_soldier_v3.png (PASS, parallel) — both on disk, both sha'd, both committed to the evidence tree.

## 2A.8 The regression sweep
The fix touched reset_pose_for_render + the main() stage order — pipeline code shared by every rigged asset. The heli (vehicle rig) and frigate (no rig) were re-rendered and re-inspected in the same container session; the loud-fail probe re-run. All PASS. Zero broken windows.

## 2A.9 THE BUNDLE-DRIFT VALIDITY RULE (the consolidation principle the record exposed)
The soldier v3 verdict was rendered on bundle 916457ea; the sealed N1 record carries deployedBundleSha256 91f4171c (the final battery bundle — heli v3, frigate v2, probe ran there). The consolidation is LEGITIMATE under an explicit rule: **a scenario verified on bundle X remains valid for bundle X+1 when the X→X+1 diff PROVABLY excludes the scenario's code path** (the 916457ea→91f4171c diff touched rig_vehicle only — vehicle rigs; the soldier is a soldier-rig asset — the exclusion is citable, not assumed). The rule's three requirements: (1) the diff is inspected, not assumed; (2) the exclusion argument is RECORDED in the results artifact; (3) any doubt = re-run the scenario on the new bundle. This is the antidote to both tediously re-running everything and the theater of inheriting verdicts across unrelated changes.

## 2A.9 What this case proves (the compressed lessons)
1. The eyes caught what every test missed (the crossed legs in a fully-valid GLB).
2. The parse redirected the fix from the plausible-wrong file (template) to the right one (pipeline order).
3. The fresh-render discriminator (v1→v2 unchanged) exposed a dead fix that had "landed" commits earlier.
4. The API probe converted a suspicion into a proof (hasattr False).
5. The convergence (v3) required BOTH: the visual PASS and the structural confirmation — and the regression sweep to license the ship.

---

# PART 3A — THE RUBRIC PER ARTIFACT CLASS (the five questions instantiated)

## 3A.1 3D ASSET (GLB + preview)
SILHOUETTE: reads as its class at spawn distance (the game's actual viewing distance — verify at THAT scale, not at full-res zoom alone). MATERIALS: baked albedo visible under the probe; procedural variation present where the template promises it (mottle on the tank, weathering on the fuel tank). PROPORTIONS: component ratios (barrel length vs hull; rotor diameter vs fuselage; deck vs hull). RELATIONSHIPS: parts CONNECTED where authored (rotor/fin, deck/hull, stock/receiver) — the floating-part hunt. FRAMING: whole artifact in frame, ground-plane excluded, hero angle. CROSS-CHECK: GLB parse (nodes/transforms/anims/skins) — the two-confirmation standard for ship.

## 3A.2 UI SCREEN (html → puppeteer)
SILHOUETTE: the layout reads as its type (dashboard/nav+content/modal). MATERIALS: tokens applied — no unstyled flash, fonts loaded. PROPORTIONS: viewport deltas honored (desktop/mobile renders differ per spec). RELATIONSHIPS: interactive elements present and positioned; no overlap/z-index accidents. FRAMING: all viewports captured; the blocked-resource BANNER visible when external resources are blocked (the visible-brokenness doctrine — a broken asset is SHOWN, never a silent blank). CROSS-CHECK: the html byte-equality (deterministic render), console/pageerror sweep (a rendering page that throws is FAIL).

## 3A.3 DASHBOARD (live app — the S9/brain-dash class)
Everything in 3A.2 PLUS: the readiness gate (capture only after the app's own signal — timers race), the live-data state (the graph/telemetry actually rendered — 3/3 nodes loaded, not an empty canvas), and the interaction sanity (a click/hover produces the expected state change; the S9 pattern's HUD text confirms loaded counts IN the frame). The capture channel is part of the artifact: an app that renders but cannot be captured cleanly is FAIL-capture (fix the harness), never PASS-by-default.

## 3A.4 CHART (the 2D line)
The founding-trauma class. SILHOUETTE: reads as a chart (axes, series, title). MATERIALS: palette/legend per spec. PROPORTIONS: axis ranges match the data (the EURUSD verification: price band 1.085→1.092 READ from the render). RELATIONSHIPS: series plotted against the right axes; labels attach to the right things. FRAMING: title/legend/labels present — the v3 incident was EXACTLY unlabeled charts passing existence checks. CROSS-CHECK: the data→render spot-check (2-3 data points read off the image against the source series).

## 3A.5 DOCUMENT/PDF (the marginal class)
SILHOUETTE: page structure reads (headers, sections, tables). The rest per spec. ViL applies to any renderable — but the grade-1/grade-2 checks (text extraction, page count) carry more weight than for pixels-only classes; ViL verifies LAYOUT semantics (overflow, clipped tables, broken columns) that text extraction misses.

---

# PART 4A — THE PROBE CALIBRATION METHODOLOGY (how measurement instruments get calibrated)

The probe (lighting rig) is the photometric instrument of the 3D loop. Calibration is a loop-within-the-loop:
1. **Render the reference artifact** under the new probe (the asset whose correct appearance is best known).
2. **Read + name the photometric deltas**: washed (blown highlights, detail lost in the top range), crushed (detail lost in shadows), flat (no modeling), color-cast (the desert_sun orange bleeding into everything).
3. **Adjust ONE axis at a time** (sun energy → ambient → backdrop), re-render, re-read. The drive's landing spots: outdoor_overcast = 3.0-tight/0.45-sky-blue (from 2.5/2.2 washed); desert_sun = 2.6/0.5/0.4 (from 6.0/1.2/1.4 blasted); world backdrop sky-blue (0.45,0.60,0.80) for preview depth.
4. **Freeze + regression**: the calibrated probe renders the WHOLE roster class; every asset re-verdicted under the new probe. The values are then SETTLED — re-tuning without a washed/crushed preview in hand is scope creep (the BUG-03/04/05 lesson, promoted to law).
5. **The instrument vs the artifact**: a probe failure is an INCONCLUSIVE measurement (fix the instrument), never an artifact FAIL (the asset was never judgeable). Confusing these sends you editing geometry to compensate for lighting — the classic wrong-file fix.

---

# PART 5A — THE OMNI-VISION INVOCATION GUIDE (the tool contract, E2E)

## 5A.1 direct mode (the engineer's second opinion)
```
omni_vision(file_path="<decoded.png>", mode="direct")
```
Reads into context. Use: multi-frame sweeps (batch file_path array — video keyframes, PDF pages), or when a structured VLM description should accompany the native read. Cost: the description enters context — budget it.

## 5A.2 api mode (the pipeline's verdict engine)
```
omni_vision(file_path=..., mode="api",
  media_context="<500+ chars: what this artifact is, what produced it, what its class promises>",
  analysis_goal="<200+ chars: the exact determination — e.g. does the render show X at rest with Y>",
  output_requirements=["verdict PASS/FAIL/INCONCLUSIVE", "named deltas list", "per-rubric-question findings"])
```
The floors are the quality gate (the bare `prompt` arg is REJECTED with a named remedy). The backend silently injects the project storyline + prior-frame context (the shadow-enhanced pattern — R1 of the Shadow Bible): the verdict is grounded in the artifact's history, not the caller's framing. Use INSIDE automated loops where reproducibility + grounding matter; the engineer's native read remains the iteration driver.

## 5A.3 The division of labor (who reads, when)
| Loop phase | Reader | Why |
|---|---|---|
| Iteration (hunting deltas) | the engineer's native read | fastest feedback; the engineer IS the loop driver |
| Ship gate | omni-vision api mode (or second model) | reproducible, grounded, independent-context |
| Regression sweep | direct mode batch | cheap breadth across many artifacts |
| Post-ship audit | fresh session, native read of the committed evidence | the STRANGER test — a session with zero context must reach the same verdict from the evidence pair |

---

# PART 6A — THE TIERED VERIFICATION ECONOMICS (when the full loop runs, when it doesn't)

The loop is not free: extraction + multimodal read + iteration is minutes per asset. The tiering policy the drive converged on:

| Tier | When | What runs |
|---|---|---|
| T0 SMOKE | every build, automated | Grade-1 only: exists, bytes, magic, non-blank std. Gates BLANK. Never cited as verification. |
| T1 LOOP | every NEW artifact + every changed artifact + every pipeline-touch regression | the full 9-step loop to PASS-with-zero-deltas |
| T2 SHIP GATE | before any ship/package | the roster re-verified (fresh extractions), evidence pairs current, results artifact sealed |
| T3 STRANGER AUDIT | major milestones | a fresh session (or external reviewer — the Grok audit) re-verdicts the committed evidence pairs with zero session context |

The drive's actual economics: ~24 T1 iterations across 11 assets + 1 T2 roster sweep + 1 T3 external audit — and the T3 audit STILL found what the internal loops had under-named (the tail rotor's "framing artifact"). The lesson compounds: **tier up on milestones**; internal loops develop blind spots exactly proportional to their authorship of the artifact.

**When NOT to run the full loop**: pure-logic artifacts with no visual surface (a registry file, a manifest) — there, Grade-2 (schema/sha) IS the verification, and a ViL pass would be theater in the other direction. The loop is for RENDERED artifacts; the doctrine is loud-fail everywhere, but eyes only where pixels exist.

---

# PART 7A — THE RESULTS-ARTIFACT LEDGER (the drive's sealed example, abridged)

The v4.1 closeout's sealed record (`.trident/container-test-results.json`, run N1-RESTPOSE-POLISH) — the schema of Part 7.4 populated, abridged to the soldier scenario:

```json
{
  "runId": "N1-RESTPOSE-POLISH",
  "container": "shark-oc-v41-n1",
  "deployedBundleSha256": "91f4171cab6a0d25dce283ef52d9fd72e142c371f1cc68a71cee08b33995c318",
  "model": "Muse Spark 1.2 Free / OpenCode Zen",
  "scenarios": [{
    "id": "N1-A-soldier-restpose", "verdict": "PASS",
    "passTokenMatch": true,
    "passToken": "ANIM:3 + _master.png + ASSET_EXPORTED + legs PARALLEL (visual)",
    "failTokenAbsent": true,
    "toolResultContext": "TUI: status success, ANIM count 3 (aim/idle/walk, 36ch each);
      GLB 121656B; preview read visually: legs parallel, boots planted;
      GLB parsed: skins 1, limb nodes symmetric rest quaternions",
    "timedOut": false }],
  "bugsClosed": { "BUG-18": "...", "BUG-25": "...", "BUG-26": "..." },
  "overallVerdict": "PASS"
}
```
Note what the record carries that prose cannot: the deployed sha (the exact bytes under test), the passToken (a tool-result string, checkable by a stranger), the channel mixture (TUI claim + extracted pixels + GLB parse), and the bugs-closed map (the loop's yield). THIS is what "logged" means.

---

# PART 8A — THE QUICK ANSWERS (the FAQ the next session will have)

**Q: The unit tests pass and the build is green — do I still need to look?**
A: Yes. Every defect in Part 5 passed the green build. The tests prove the machinery; the loop proves the artifact.

**Q: The preview is PERFECT but the GLB parse disagrees — which wins?**
A: Neither is "wrong" — the disagreement IS the finding. It means the preview and the export pipelines diverge (exactly BUG-25: preview posed, export at rest). Diagnose the divergence; do not pick a winner.

**Q: How many iterations before I give up on an asset?**
A: ~5 (the 5-iteration rule, §3.4). Then stop delta-hunting and escalate: re-derive the expectation, re-verify the stage order, re-check the instrument.

**Q: Can the agent that wrote the renderer do the visual verdict?**
A: Yes, IF the verdict consumes a fresh extraction of the decoded file and the rubric runs against the pre-written spec expectation (the fresh-read discipline). No, if "the verdict" is the generation context recalling what it intended. The independent-reader law bans the second, licenses the first. For ship gates, tier up (§6A T2/T3).

**Q: What if the render looks fine but I can't articulate WHY I trust it?**
A: Then the verdict is not rendered yet. Run the five questions (§3.1) and enumerate: every expected element found/missing/wrong. Trust without enumeration is AP-6 waiting to ship.

**Q: omni-vision direct vs api — which for my loop?**
A: Iterations: direct (or native read — fastest). Ship gates and pipeline-embedded verdicts: api mode (grounded, reproducible). Audits: a stranger session. (§5A.3.)

**Q: The defect only shows at one angle/state — is verifying the hero frame enough?**
A: For the hero-frame promise, yes. For state-carrying artifacts (ANIM clips, interactive UI), no — verify the states (AP-8): parse the clips, capture the states, sweep the angles.

**END OF DEEP-DIVES.**

---

# PART 9A — DEEP-DIVE: THE HELI CASE, E2E (the exoneration + isolation disciplines)

The helicopter case is the bible's second reference execution — and it exercises techniques the soldier case does not: the BYTE-IDENTICAL EXONERATION, the GIT-DIFF ISOLATION, and the ARITHMETIC CONFIRMATION of a visual verdict.

## 9A.1 The expectation (written from the template's own geometry)
"Attack helicopter: fuselage + stub wings + sensor ball + gun; main rotor (4 blades) seated ON the mast at (0.2, 0, 2.05); tail boom aft to the vertical fin at x≈-3.7; tail rotor (3 blades) seated ON the fin surface; ANIM:2 spin clips on the rotors." — derived from templates-air.ts buildScript, before any render.

## 9A.2 Render v1 (bundle 7b6387fa — the soldier's BUG-25 fix deployed)
Extraction: preview 1,141,918B, transport clean. Read: **FAIL — tail rotor floats far off the airframe, up-left in the sky; main rotor floats high above the mast with a visible gap to the fuselage.** The deltas are named WITH magnitudes and frame-directions — and this naming is what everything after hinges on.

## 9A.3 The wrong first theory — and its cheap refutation
Working theory: the render-pose reset (new code in this bundle) flung the rotors. THE EXONERATION EXPERIMENT: the reset was extended to object-level animation and re-run — the new extraction came back **byte-identical: 1,141,918 bytes**. Same bytes = the change did nothing = the theory is dead. A byte-identical re-render is the loop's cheapest decisive experiment: zero interpretation, pure discrimination. (It also proved the extended reset was inert for this artifact class — a finding in its own right, later load-bearing when the soldier needed the object-level branch.)

## 9A.4 The isolation step (git-diff, the second discriminator)
With my code exonerated, the remaining delta vs the (admittedly under-named) roster build was the polish edit. `git diff 130117c -- src/omni-canvas/templates-air.ts` showed EXACTLY three Y-value sites (0.14→0.12) plus line-join formatting. Arithmetic: 0.02 units cannot displace a rotor by units. THE POLISH IS INNOCENT. Therefore the defect PREDATED the drive — re-reading the roster record: the tail rotor had read "detached…framing artifact" there too. The defect had SHIPPED once already, under-named.

## 9A.5 The owner-file read (the structure branch, done properly)
templates-air.ts join_into() joins with the FIRST part as active → the joined object keeps tail_hub's transform — geometry preserved, no displacement. rig_vehicle(): creates spin_pivot EMPTY at the rotor's world position, parents the rotor, sets matrix_parent_inverse = empty.matrix_world.inverted(). THE READ FOUND IT: the matrix_world read sits immediately after the empty.location assignment — and Blender's matrix_world is STALE (identity until a depsgraph update).

## 9A.6 The arithmetic confirmation (visual verdict + math = EXTRACTED)
With matrix_parent_inverse = identity, child_world = empty.M @ child.M — each rotor displaced BY ITS OWN POSITION VECTOR:
- main rotor at (0.2, 0, 2.05) → renders ~(0.4, 0, 4.10): ~2 units high ✓ matches "floats high above the mast"
- tail rotor at (-3.7, 0.12, 2.05) → ~(-7.4, 0.24, 4.10): far behind-left-high ✓ matches "up-left in the sky"
The named deltas' DIRECTIONS and MAGNITUDES matched the faulty-transform arithmetic. The visual verdict and the mechanism confirmed each other — the classification is now EXTRACTED fact, not inference.

## 9A.7 The fix + v3 convergence
`bpy.context.view_layer.update()` between the location assignment and the matrix read (blender-headless.ts, rig_vehicle). Fresh setup, fresh render, fresh extraction (1,160,686B — NEW render). Read: **main rotor ON the mast; tail rotor AT the fin** — PASS with one minor named delta (tail blades clip the fin slightly — greybox tier, logged). GLB re-parse: 53,252B, ANIM:2 [spin, spin.001] — the clips intact. Regression sweep: soldier re-verified (parallel legs held), frigate rebuilt + verified (deck in-hull held). Zero broken windows.

## 2A.9 THE BUNDLE-DRIFT VALIDITY RULE (the consolidation principle the record exposed)
The soldier v3 verdict was rendered on bundle 916457ea; the sealed N1 record carries deployedBundleSha256 91f4171c (the final battery bundle — heli v3, frigate v2, probe ran there). The consolidation is LEGITIMATE under an explicit rule: **a scenario verified on bundle X remains valid for bundle X+1 when the X→X+1 diff PROVABLY excludes the scenario's code path** (the 916457ea→91f4171c diff touched rig_vehicle only — vehicle rigs; the soldier is a soldier-rig asset — the exclusion is citable, not assumed). The rule's three requirements: (1) the diff is inspected, not assumed; (2) the exclusion argument is RECORDED in the results artifact; (3) any doubt = re-run the scenario on the new bundle. This is the antidote to both tediously re-running everything and the theater of inheriting verdicts across unrelated changes.

## 9A.8 The case's distinct lessons
1. **Byte-identical re-renders exonerate cheaply** — run the null experiment before building theories.
2. **git-diff isolates owner candidates mechanically** — when the suspect set is "everything changed recently," the diff IS the experiment.
3. **Under-named deltas let defects ship** — the roster's "framing artifact" note licensed a real bug for a full session. Name magnitudes; magnitudes arithmetic-check.
4. **The visual verdict + the transform arithmetic are dual descriptions of one fact** — when they agree, the classification is extracted; when they disagree, one of them is about the wrong object.

---

# PART 9B — WHEN THE LOOP MISFIRES (the loop's own failure modes)

The loop is a decision system; it has its own defect classes. Each: the misfire, the cost, the countermeasure.

## 9B.1 THE UNDER-NAMED DELTA (the costliest misfire observed)
The roster session logged the tail rotor as "reads detached — framing artifact" — a verdict that was TRUE about the frame and FALSE about the world. Cost: the defect shipped, and the closeout spent two extra renders rediscovering it. COUNTERMEASURE: deltas carry magnitudes + directions (Part 3.2); "framing" explanations require a PROOF (a second angle render showing the gap close — which was never taken). An explanation that was never tested is a guess wearing a verdict's clothes.

## 9B.2 THE OVER-FIRING RUBRIC (the false-FAIL storm)
A rubric tuned too tight fails clean artifacts: style preferences graded as defects, greybox tier flagged against a production bar. Cost: iteration burn on non-defects; real deltas drown. COUNTERMEASURE: the expectation is written from the SPEC'S TIER (the roster's bar was greybox — silhouette + bake proof, NOT production art); the clean-control test (7.1 #2) keeps the rubric honest; tier changes are OPERATOR decisions, not reader drift.

## 9B.3 THE INCONCLUSIVE SHELTER (dodging hard verdicts)
INCONCLUSIVE exists for unjudgeable MEASUREMENTS. Misfire: using it to avoid a hard call on a judgeable render ("kind of ambiguous, re-render") — an infinite deference loop. COUNTERMEASURE: INCONCLUSIVE requires a NAMED measurement defect (washed/cropped/corrupt/wrong-probe); "I'm not sure" is not a measurement defect — it is an under-read; re-read with the rubric enumerated.

## 9B.4 THE FIX-CHASING REGRESSION (whack-a-mole)
Fix A shifts the defect to B (the camera fix that fixed the black frame but cropped the radar — iteration 2 of radar_station). Misfire pattern: treating each re-render as a NEW unrelated defect. COUNTERMEASURE: within one asset's loop, consecutive deltas in the SAME pipeline stage are ONE defect wearing two symptoms — fix the stage's root, not each symptom (the radar's real root was the fit's aspect handling, not "framing" twice).

## 9B.5 THE EVIDENCE-PAIR GAP (the unauditable pass)
A PASS logged without its extraction (no sha, no file, "I looked at it in the container"). Cost: the T3 stranger audit cannot re-verify; the claim decays to prose. COUNTERMETER: no extraction record, no verdict — the results-artifact schema (7.4) REJECTS scenarios without the extraction block (the enforcement is the schema).

## 9B.6 THE TIER-CONFUSION SHIP (smoke dressed as verification)
The quietest misfire: the pipeline ships on T0 smoke (non-blank std) and the report cites it as "verified." No lie was told in any single sentence; the lie is the equivocation between grades. COUNTERMEASURE: verdict LANGUAGE is grade-tagged — "smoke PASS" / "ViL PASS (visual verdict, evidence pair sha'd)". The words carry the grade; the grade carries the proof burden.

---

# PART 10A — THE INTEGRATION CHECKLIST (wiring ViL into a NEW tool — the pre-build gate)

Before building a tool that produces visual artifacts, answer all ten; any NO is a design gap:
1. Does every pipeline terminus produce an EXTRACTABLE artifact (a file, not just a log)?
2. Is there a written expectation for the artifact BEFORE any render (spec-derived)?
3. Is the extraction channel defined with its three checks (bytes/magic/sha)?
4. Is the reader independent (fresh read / api mode / second model) and does the tool PREVENT self-grading shortcuts?
5. Does the verdict enum include INCONCLUSIVE, and is no-client INCONCLUSIVE tested?
6. Is the classification tree written for THIS artifact class (script/pipeline/transport/environment — with the class's own examples)?
7. Is the results-artifact schema enforced (a verdict without its extraction block is rejected)?
8. Are the iteration + regression disciplines wired (fresh-extraction law; sweep after pipeline fixes)?
9. Does the zero-hint battery exist for the loop (planted defect, clean control, dead channel, unjudgeable frames, mutations)?
10. Is the tiering policy written (what ships on T0 smoke vs T1 loop vs T2 sweep vs T3 stranger)?

Omni-canvas passed these by its v4.1 closeout; brain-dash inherits them by design (the ViL screenshot gate is a pipeline stage, not a hope).

---

# PART 11A — THE ONE-PAGE PROCESS CONTRACT (paste into any tool's spec)

```
THIS TOOL PRODUCES VISUAL ARTIFACTS. THEREFORE:
1. Every artifact is extracted byte-exact (bytes/magic/sha) before any verdict.
2. Every artifact is LOOKED at by an independent reader against a spec-written expectation.
3. Verdicts are PASS | FAIL | INCONCLUSIVE; deltas are NAMED (component, relationship,
   location, magnitude); "looks off" is not a delta.
4. Every FAIL delta is classified: SCRIPT | PIPELINE | TRANSPORT | ENVIRONMENT —
   and the fix lands in the tree's owner file.
5. A fix is re-rendered, re-extracted, re-read. Byte-identical = the fix did nothing.
6. Pipeline fixes trigger a regression sweep of all prior PASSes.
7. INCONCLUSIVE = named measurement defect; no-client = INCONCLUSIVE, never approve.
8. Every verdict is logged with its extraction block + evidence pair; the schema
   rejects verdicts without extractions.
9. Iterations are counted; ~5 failures = systematic defect = escalate past deltas.
10. The loop itself is battery-tested: planted defect, clean control, dead channel,
    unjudgeable frames, mutation checks.
```

---

# PART 12A — THE FRIGATE CASE, ABRIDGED (the shared-script fix + the two-for-one verification)

The shortest full case, kept because it demonstrates ONE-EDIT-TWO-ASSETS verification:
- EXPECTATION (spec): deck plate within the hull silhouette at every station; destroyer and frigate share `warshipScript()` — one geometry source.
- RENDER v1: deck proud of the hull sides at the stern taper on BOTH warships (the shared script means shared defects — the delta appeared in two previews).
- CLASSIFY: GLB node positions showed deck width > hull profile width → SCRIPT → templates-warships.ts:210, the single deck x-scale.
- FIX: `HW * 1.70 → HW * 0.96` (deck half-width 0.85·HW → 0.48·HW vs hull half-width 0.5·HW — a 4% inset, the smallest change satisfying the audit's literal).
- RE-RENDER + VERIFY BOTH: frigate `frigate_deck_in_hull.png` PASS (stern flush, minor delta: stern tip marginally proud — logged); destroyer re-rendered PASS under the same edit. THE SHARED-SOURCE LAW: when assets derive from one script, one fix = both re-verified; the edit's blast radius is the derivation graph, and the loop's sweep follows THAT graph, not the file list.

---

# PART 13A — THE EVIDENCE-PAIR NAMING CONVENTION (why file names are load-bearing)

The drive's evidence files: `soldier_parallel_legs.png`, `frigate_deck_in_hull.png`, `heli_rotors_seated.png`, `s9_browser_scene.png`. Each name states the PROVEN EXPECTATION — the thing the image demonstrates. This is deliberate:
1. A stranger auditing the package reads the evidence DIRECTORY as a verification ledger — no doc lookup needed to know what each PNG proves.
2. The name is the assertion; the bytes are the proof; the sha in the manifest binds them.
3. Re-verification is greppable: "has anyone proven the heli rotors seat?" → the file exists → check its sha against the manifest → the proof stands (or the sha drifts → re-verify).
Convention: `<artifact>_<the-proven-expectation>.png` — expectation in present tense, positive form. Never `fixed.png`, `v2.png`, `final_final.png` — a name that doesn't state the proof is a name that rotts.

---

# PART 14A — THE MINIMUM READ FOR THE IMPATIENT (the 20-line bible)

If you read nothing else:
1. Write the expectation from the spec BEFORE rendering.
2. Extract byte-exact; check bytes/magic/sha before reading.
3. LOOK with fresh eyes; name deltas with magnitudes; "looks off" is banned.
4. Classify: structure-wrong=SCRIPT, structure-right/pixels-wrong=PIPELINE, bytes=TRANSPORT, engine=ENVIRONMENT.
5. Fix the owner file the tree names. Never the symptom.
6. Re-render, re-extract (new sha), re-read. Byte-identical = the fix did nothing.
7. Sweep prior PASSes after pipeline fixes.
8. INCONCLUSIVE is honest; no-client never approves.
9. Log verdict + deltas + extraction + evidence pair, or it didn't happen.
10. ~5 failed iterations = systematic defect = stop delta-hunting, escalate.
11. Pixel-std gates blank, never wrong. Structural PASS never means visual right.
12. The stranger must be able to re-verify from your record alone.

---

# PART 15A — COLOPHON + THE CANON REGISTRATION

**Provenance:** written 2026-08-25 from the OMNI-CANVAS v4.1 drive + closeout session's live record — every command, byte count, sha, verdict, and bug in this bible is drawn from that build's artifacts (`.trident/container-test-results.json`, `Context_Management/DEBUG_LOG.md`, `Context_Management/EVIDENCE_STATE.md`, `evidence/previews/*`, and the sealed `Ship_Packages/Omni_Canvas_Tool_v4.1/`). The bible's claims are re-verifiable from those artifacts by any stranger, which is the bible's own standard applied to itself.

**Companion registration:**
- The OMNI-CANVAS project's COMPACTION_SURVIVAL.md §4 (doc map) and the sealed v4.1 package's HANDOVER.md reading order reference this bible as the ViL process authority.
- The vil-critique tool (omni-canvas `src/omni-canvas/modules/vil-critique.ts`) is this bible's §7.3 contract, implemented.
- BrainForge (the brain-graph + brain-dash tool, design pending DPL2) inherits this process as pipeline stages: the ViL screenshot gate is §7.3 wired as code.

**The maintenance law:** this bible grows by APPENDIX (the A-parts pattern) — new cases, new misfires, new artifact classes append as numbered parts; existing parts are corrected in place only for factual error. A bible that rewrites its history teaches its readers to distrust it.

**The final law, one sentence:** the pixels are the truth, the extraction is the evidence, the reader is the judge, the delta is the work order, the tree is the routing, the fix is at the root, the re-render is the proof, the pair is the record — and a session that skips any link in that chain is not verifying, it is performing.
