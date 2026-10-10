# Verification

The rule for this project: **a feature is not done until `./verify.sh` passes and
the contact sheet has been visually inspected.** No exceptions.

## Running it

```bash
./verify.sh
```

Steps, in order:

1. **engine** — downloads the pinned Godot 4.4.1 into `.tools/` if missing (gitignored)
2. **import** — reimports the project. Required: `class_name` globals are registered
   during import, so a newly added class is invisible until this runs
3. **logic tests** — headless, no display
4. **visual captures** — boots scenes, drives scripted input, writes contact sheets

Exit code 0 means every step passed. Output lands in `artifacts/<name>/`:
`sheet.png` (contact sheet), `frames/` (individual PNGs), `godot.log`.

## Adding a visual capture

1. Write an input script in `tools/verify/inputs/`:

```json
{
  "events": [
    { "frame": 10, "press": ["move_right"] },
    { "frame": 45, "tap": ["attack"], "tap_frames": 2 },
    { "frame": 95, "release": ["move_right"] }
  ]
}
```

Supported keys: `press`, `release`, `tap` (auto-releases after `tap_frames`,
default 2). Every action name is validated against the InputMap at load — a typo
fails the run rather than silently capturing nothing.

2. Register it in the `CAPTURES` array in `verify.sh`:

```
"res://levels/Arena01.tscn|ground_combo|180|6|res://tools/verify/inputs/ground_combo.json"
```

Format: `scene|name|frames|every|input_json`.

## Adding a logic test

Drop a file in `tools/test/cases/` named `test_*.gd`, extending `TestCase`.
Methods named `test_*` run automatically. `before_each` / `after_each` are
available. Assertions: `assert_true`, `assert_false`, `assert_eq`,
`assert_almost_eq`.

## Renderer note

Captures run under `gl_compatibility` + `opengl3` on a software rasteriser
(llvmpipe), because this container has no Vulkan ICD. The shipping Windows
build uses **Forward+**.

Geometry, animation, physics and gameplay are identical between the two — those
are what the harness verifies. **Lighting and post-processing fidelity are not
verified here** and must be checked on real hardware. That is the one gap in
this pipeline, and the reason each phase also ships a build for manual testing.

## Failure modes it catches

Both are deliberately tested:

- Godot errors and script errors — the log is the real signal, since Godot
  reports script failures without setting a non-zero exit code
- Failing assertions — runner exits 1 and names the case
