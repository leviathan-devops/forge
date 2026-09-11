# Vision-in-the-loop on Grok Build (FORGE mapping)

Authoritative process: `docs/bibles/VISION_IN_THE_LOOP_ENGINEERING_BIBLE.md`.  
This file is the **earth mapping** onto Grok Build tools. It does not weaken the bible.

## Capability (this session, proven)

| Need | Grok Build native? | How |
|------|--------------------|-----|
| Look at a screenshot / PNG / JPEG | **Yes** | `read_file` on the image path. The image enters the model as vision (grok-4.6 is image→text). Proven 2026-09-08 on `forge-launch-screenshot.png` (launch menu, two cards, cyan accent). |
| User-paste image chips | **Yes** | Composer image paste / drag. Config: `models.image_description`. |
| Generate images | **Yes** | tools `image_gen`, `image_edit` (Imagine). Slash `/imagine`. |
| Generate videos | **Yes** | tools `image_to_video`, `reference_to_video`. Slash `/imagine-video`. |
| Understand a local `.mp4` as a single native video token | **No** | grok-4.6 modalities are **text, image → text**. Official docs: [Image Understanding](https://docs.x.ai/docs/guides/image-understanding), [Grok 4.6](https://docs.x.ai/developers/models/grok-4.6). X Search `enable_video_understanding` is for **X posts**, not guest sim recordings. |
| E2E demo video verdicts | **Yes, via frames** | `ffmpeg` extract → `read_file` each PNG → named-delta verdict. Same loop OpenCode used with omni-vision. |

Limits from SpaceXAI docs: images jpg/png, max 20MiB, unlimited count, `detail=high` available on the API. Grok CLI `read_file` is the agent path; do not invent an `omni_vision` tool that does not exist here.

## Official enablement (already on)

Nothing extra to install for screenshot ViL. Image/video **generation** is already exposed in this CLI (`features.image_gen` / `features.video_gen` in `~/.grok/docs/user-guide/26-config-reference.md`). If a future session is missing Imagine tools, set in `~/.grok/config.toml`:

```toml
[features]
image_gen = true
image_edit = true
video_gen = true
```

Image **understanding** is the chat model itself (grok-4.6), not an Imagine flag.

## Test rig (VM is not the product)

The macOS forge VM is a **headed test environment**. Load it on **container-virtual-display** and LOOK:

1. `setup-display.sh forge 6301 /home/leviathan/Grok_Build/projects/forge` (`--gpus all`, Weston `:0`).
2. `./docker/run-forge-vm.sh up` / `start-tahoe` (image `macos-forge:master`, volume `forge-vm-data`).
3. On DISPLAY=:0 open VNC `127.0.0.1:5901` (or `vnc-host`) so the sim is visible on that virtual display.
4. Guest: `xcodebuild` + `simctl boot "iPhone 17 Pro"` + install FORGE.app.
5. `simctl io booted screenshot|recordVideo` and/or `scrot` on the headed display.
6. `read_file` the PNGs. Verdict. Loop.

Mode 1 on the phone does **not** talk to this VM. Agent is self-contained; LLM is device `fetch()` only.

## FORGE E2E video loop (the load-bearing recipe)

Matches bible 9 steps + recovery plan Phase 3/4 recording pipeline.

```bash
# 1. On guest, record the journey (one file per continuous use-case)
ssh -p 50922 user@127.0.0.1 \
  'xcrun simctl io booted recordVideo --codec h264 --force /tmp/J1.mp4'
# …drive the app… then stop recording, pull:
scp -P 50922 user@127.0.0.1:/tmp/J1.mp4 \
  /home/leviathan/Grok_Build/projects/forge/tmp/evidence/vil/J1.mp4

# 2. Extract byte-exact frames on the host (Grade 1)
mkdir -p tmp/evidence/vil/J1-frames
ffmpeg -y -i tmp/evidence/vil/J1.mp4 -vf fps=2 tmp/evidence/vil/J1-frames/f%04d.png
python3 scripts/vil-frames.py tmp/evidence/vil/J1-frames   # magic + sha + bytes

# 3. LOOK — read_file on representative frames (not a glance)
#    Write the expectation BEFORE looking. Verdict = PASS | FAIL | INCONCLUSIVE.
# 4. Name deltas. Classify SCRIPT vs PIPELINE vs TRANSPORT vs ENVIRONMENT.
# 5. Fix at the root file the tree names. Re-record. Re-inspect. Log the pair.
```

Banned: file-size as proof, "looks good", generator self-grade, host pytest as CONTAINER_TEST, approving when the reader could not see.

## Screenshot loop (faster T1)

```bash
# guest sim screenshot
ssh -p 50922 user@127.0.0.1 'xcrun simctl io booted screenshot /tmp/s.png'
scp -P 50922 user@127.0.0.1:/tmp/s.png tmp/evidence/vil/s.png
# host VM GUI
./docker/run-forge-vm.sh vnc-host
# or vncsnapshot against the mapped display when VNC is up
```

Then `read_file tmp/evidence/vil/s.png` and apply the five rubric questions.

## OpenCode omni-vision vs Grok

OpenCode used plugin `omni_vision(file_path, mode=direct|api)`. That plugin is **not** a Grok skill; it was not in `~/.config/opencode/skills/` (it lives under OpenCode plugins). Grok replacement:

| OpenCode | Grok Build |
|----------|------------|
| `omni_vision` direct | `read_file` on PNG/JPEG |
| `omni_vision` api (structured verdict) | `read_file` + written rubric in the prompt; optional second-session stranger audit |
| video → keyframes inside omni-vision | `ffmpeg -vf fps=2` then `read_file` batch |
| zai-vision / `see.sh` (ZCode) | not required; grok-4.6 already sees images |

Do not call tools named `omni_vision` here. They will not exist.
