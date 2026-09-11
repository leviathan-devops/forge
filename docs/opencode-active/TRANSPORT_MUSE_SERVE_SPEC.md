# TRANSPORT PATCH SPEC — muse via host-serve session (MissingSessionID resolution)
Date: 2026-09-07 · Status: AUTHORITATIVE · Predecessor: N9_MUSE_CONTINUATION.md,
CLEANUP_SPEC_V1.md, FORGE_CLEANUP_DPL1_SPEC.md, problem-solving artifact
`GENERATED_ARTIFACTS/PROBLEM_SOLVING/1_CLASSIFICATION.md` (audited below).

## §0 Problem (one sentence)
Zen free tier now rejects sessionless gateway calls (`MissingSessionID`, proven
2026-09-07: N9-good minimal probe 400s; deepseek upstream-unavailable; muse chat
still 500), so the on-device engine's direct `opencode.ai/zen/v1/responses` call
dies with LLM error 400 and no Mode-1 beat is tapeable — while the SAME muse model
replies `SERVE_PROBE_OK` through a host-serve session with zero keys.

## §1 Evidence (all pasted-output verified this session)
- P1 minimal `/responses` + public → `400` (was `resp_6a91…` in N9).
- P2 system-role → `MissingSessionID: free tier can only be used in OpenCode`.
- P3 deepseek chat → `server_error: Model is unavailable` (transient signature).
- P4 muse chat → 500 (known broken converter, unchanged).
- Probe B: `POST 127.0.0.1:8090/session` → `ses_f850fc133ffezKUW8TqkziaUZF`;
  `POST /session/{id}/message` `{providerID:opencode, modelID:muse-spark-1.2-contributor-free,
  agent:trident}` → 200 assistant msg, 15 output tokens, text `SERVE_PROBE_OK`.
- TapeA-v3 v0060/v0170: `LLM error 400` (turn never ran — pixels-second ordering).

## §2 Fix plan (engine transport branch; model, keys, and architecture unchanged)
In `forge-bundle.js` `runForgeAgent`, openai branch: add serve-session transport
selected when `apiBase` points at the LAN serve host (192.168.100.7:8090) AND model
is muse. Contract:
- `ensureServeSession(apiBase)`: `POST {apiBase}/session {}` → `{id: ses_…}`;
  persist id in memory; on 404 once, recreate once; on failure return
  `llm-error:noserve` with loud chat status (fail-closed, P2 guard semantics).
- Turn: `POST {apiBase}/session/{id}/message` `{parts:[{type:text,text:userInput}],
  model:{providerID:"opencode",modelID:model},agent:"trident"}`; poll
  `GET {apiBase}/session/{id}/message?limit=1` until an assistant message with
  `finish` arrives or 180s; feed `parts[].text` (+ tool-call parts if the serve
  returns them) into the EXISTING downstream (llmText → parseAgentBlocks / tool
  loop unchanged).
- Direct-zen museMode branch STAYS as fallback (transient legs recover; N9 shape).
- Selection: serve branch when `apiBase` contains `192.168.100` (the MC-tested LAN
  route); zen-direct otherwise. No new config keys; no API keys anywhere.
- Pseudocode (runs inside the existing `provider === "openai"` block):
```
if (isServeBase(apiBase) && museMode) {
  ses = await ensureServeSession(apiBase)            // fail-closed loudly
  post = await native.call("httpRequest", {url: apiBase+"/session/"+ses+"/message",
    method:"POST", headers:{"Content-Type":"application/json"},
    body: JSON.stringify({parts:[{type:"text",text:userInput}],
      model:{providerID:"opencode",modelID:model}, agent:"trident"})})
  llmText = await pollAssistantText(apiBase, ses, 180000)   // GET message loop
  lastUsage = {prompt_tokens: est, completion_tokens: est}  // serve usage optional
} else { <existing museMode /responses + chat/completions paths unchanged> }
```

## §3 Waves
- Wave A (this spec): bundle-template edit + node --check + greps + bun battery
  (translator + hooks, expect 23/0) + commit.
- Wave B: rsync → xcodegen → xcodebuild SUCCEEDED → user install → prime →
  TapeA-v4 DUR=350 → 1fps extract → watch (v0060 turn MUST show streaming, not 400)
  → VERDICT.md zero-delta → checkpoint pending-ship-approval-v2.

## §4 Testing
- Unit/script: translator suite + hook suite re-run green; NEW: serve-session mock
  test (stub native.call httpRequest/message-poll, assert branch selection +
  fail-closed on 404) — adversarial: 404 recreates once then fails loud; malformed
  message JSON → llm-call-failed, never silent.
- Live: TapeA-v4 beats (§6 of CLEANUP_SPEC_V1) + v0060 streaming gate.
- Container-equivalent (no trident-container-test in this runtime's toolset —
  reported BLOCKED with this exact reason): bun suites executed with pasted outputs
  + Law-1 tape ledger + frame reads. iOS artifacts verify on the Tahoe guest
  (Xcode/sim), which IS their real runtime.

## §5 Anti-patterns
1. Paid-key fallback (banned absolutely). 2. Provider switch on 400 (the 400 is
   deterministic policy — switching hides it). 3. Waiting without re-probe protocol.
4. Editing forge/src stubs (F1). 5. Passing without v0060 streaming pixels.

## §6 Success
1. `node --check` exit 0; `grep -c serve-session` ≥ 3; existing 2/2/2 counts intact.
2. Battery 23/0 + new serve-branch tests green. 3. BUILD SUCCEEDED + install + prime.
4. TapeA-v4 v0060 shows muse streaming (no 400) → full beats → VERDICT zero-delta.

## §7 Resume anchors
This file → CLEANUP_SPEC_V1 §3 runbook → EVIDENCE_STATE N10 rows. Next: implement §2.

## §8 Open questions — none. Proceed.

## Appendix A — audit of the problem-solving artifact (used, not trusted blindly)
Corrections applied: port is the EXISTING 8090 serve (not a new 4096); engine patch
lands in the bundle template (forge/src is stubs — F1); no `.trident/forge-serve-session.json`
file needed (in-memory id + recreate-on-404 is sufficient and leaves no stale state);
message endpoint shape taken from the LIVE probe above, not the artifact's sketch.
Verdict: direction adopted, details re-grounded — no unresolvable gaps.
