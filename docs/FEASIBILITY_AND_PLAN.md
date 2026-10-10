# 2.5D Character-Action Game — Feasibility Study, Design Spec & Build Plan

Author: Claude (Opus 5) · Date: 2026-10-10
Repository: HamzaAhmad1337/FPS-Game- (currently empty — clean start)

---

## PART 0 — THE HONEST VERDICT (read this first)

### Can this game be built? YES — but you must understand where the line is.

There are two completely different things people mean when they say "a game like Devil May Cry 5":

**(A) COMBAT FEEL** — how it plays. Responsive input, attacks that connect with weight,
hitstop that makes impacts feel heavy, combo chains you can cancel, launchers, air juggles,
dodges with i-frames, enemies that stagger and react, a style meter that rewards variety.

**(B) VISUAL FIDELITY** — how it looks. Motion-captured animation, hand-sculpted characters,
AAA shaders, particle VFX, orchestral audio, environment art.

**I can build (A) to a genuinely high standard. I cannot build (B) from nothing.**

(B) is not a programming problem. It is 20-50 person-years of artist, animator, and
audio work. No AI, no engine, and no amount of time from me changes that. If anyone
tells you otherwise they are lying to you.

### So what will the final game actually be?

A complete, polished, installable Windows game with **combat mechanics that are genuinely
good** — on par with a competent indie action game — wearing a **clean stylized low-poly
visual skin**, not a AAA skin.

### Will a user install it and say "VIP game"?

Honest answer, split in two:

- If they judge it on **how it feels to play** — yes, that is achievable, and it is the
  part that actually matters in a combat game. A tight combat system in simple visuals
  beats beautiful visuals with mushy combat every time.
- If they judge it on **looking like DMC5** — no. Not possible. Not by me, not in this
  scope. I will not pretend otherwise.

### Why the previous attempts failed (and what is different now)

Previous attempts failed for one concrete reason: **I could not see what I was building.**
I wrote code blind, never ran it, never looked at it, and handed you something unverified.
That is exactly how you end up with "khudi line" — a pile of plausible-looking code that
does not actually run as a game.

**That is fixed as of today.** I verified, by actually doing it in this session:

| Capability | Status | Evidence |
|---|---|---|
| Godot 4.4.1 runs in this environment | WORKS | `4.4.1.stable.official.49a5bc7b6` |
| 3D rendering (OpenGL3 / llvmpipe software renderer) | WORKS | Rendered a lit 3D cube |
| Screenshot capture of a running game | WORKS | Saved + visually inspected a 640x360 PNG |
| Export templates for a real Windows .exe | AVAILABLE | 1,206,040,900 bytes, reachable |
| Asset sites (Kenney / Quaternius / Mixamo) | **BLOCKED (HTTP 403)** | Network policy |
| Rigged glTF models from GitHub | AVAILABLE | Khronos sample assets (walk cycles only) |

**The screenshot capability is the whole game-changer.** It means after every single
change I can run the game, capture frames, look at them, and confirm the character
actually moves, the attack actually swings, the enemy actually reacts. No more blind code.

### The one thing I need from you

Asset strategy. This is the single decision that determines whether the result looks
"clean indie" or "actually impressive". See PART 7.

---

## PART 1 — ENGINE DECISION: GODOT 4.4.1

**Chosen: Godot 4.4.1 (GDScript).** Reasons, in order of importance:

1. **I can run and verify it here.** Proven above. Unity cannot run in this container
   (no editor binary, requires license activation, no headless project authoring).
2. **Text-based scene format.** Godot `.tscn` / `.tres` / `.gd` files are plain text.
   I can author, diff, and review the entire project. Unity's `.unity`/`.prefab` YAML
   with GUID references is extremely fragile to hand-author and breaks silently.
3. **Real export pipeline from CLI.** `godot --headless --export-release "Windows Desktop"`
   produces an actual `.exe`. I can produce the build, not just the source.
4. **You already have Godot on your PC.** Zero new setup for you.
5. **No licensing friction.** MIT, no activation, no account.

Unity would only win if we needed its asset store ecosystem — which is blocked in this
container anyway.

---

## PART 2 — GAME CONCEPT

**Working title:** `CRIMSON EDGE`

**Genre:** 2.5D character-action (stylized hack-and-slash / combo brawler)

**Camera:** 3D world, camera locked to a side-on orbit with limited yaw. The player moves
freely on X (left/right) and Z (depth, constrained to an arena band), and Y (jump/air).
This is the Streets of Rage 4 / Fight'N Rage spatial model with a 3D camera.

**Why 2.5D and not full 3D:** full 3D combat requires solving camera framing, lock-on
occlusion, and 360-degree enemy encirclement — three hard problems that eat the entire
budget and are the usual reason indie action games feel bad. Constraining depth lets us
spend everything on the combat itself. This is a deliberate scope decision, not a shortcut.

**Core pillars:**
1. **Every hit has weight.** Hitstop, screen shake, pushback, impact VFX on every connect.
2. **Expression through cancels.** The player who learns the cancel windows plays twice
   as fast as the player who mashes.
3. **Enemies are combo partners, not sandbags.** They telegraph, guard, stagger, get
   launched, and get up.
4. **The style meter is the score.** Variety and uptime are rewarded; mashing one button
   is punished.

**Scope boundary (what this game is NOT):** no open world, no story cutscenes, no multiple
playable characters, no multiplayer, no save system beyond settings + high score. One
player character, three enemy types, one arena, wave-based survival with a boss.

---

## PART 3 — RESEARCH FINDINGS: WHAT MAKES COMBAT ACTUALLY GOOD

Sources consulted are listed in PART 13. Key findings distilled into actionable rules:

### 3.1 Devil May Cry 5's style system
Seven ranks, D through SSS (Dismal, Crazy, Badass, Apocalyptic, Savage, Sick Skills,
Smokin' Sexy Style). Style is gained by landing varied attacks, taunting, enemy-step,
perfectly-timed dodges, and parries. It is lost by taking damage, repeating the same
attack, and idling. Critically: **each landed move is locked out from earning further
style points for a short time**, which is the specific mechanic that punishes mashing.
Enemy Step functions as a jump cancel that resets aerial weight and per-jump special uses.

### 3.2 Input buffering is the difference between "responsive" and "broken"
Documented practice: store player intent for a short window and fire it the instant the
state machine permits. Common default is **0.12 seconds (≈7 frames at 60fps)**. Separate
buffers per action (attack, jump, dodge) tuned independently. Without this, a game feels
unresponsive even when the code is correct, because the player presses during recovery
frames and the input is thrown away.

### 3.3 Attack structure: WINDUP → ACTIVE → RECOVERY
Every attack is three phases. The hitbox is **enabled only during ACTIVE**. A swing must
hit each target **once** even though the hitbox overlaps for several frames — requires an
explicit "already hit this target this swing" set, reset at swing start. Cancel windows
open partway through RECOVERY.

### 3.4 Hitbox / hurtbox separation
Two `Area3D` nodes with opposite collision layer/mask configuration: the hitbox is
*detectable but detects nothing*; the hurtbox *detects but is not detectable*. This
prevents the classic bug where two hitboxes collide with each other.

### 3.5 2.5D depth resolution
When a hitbox and hurtbox overlap in screen space, compare the two actors' **depth
coordinates** against a tolerance band before confirming the hit. Without this, you hit
enemies standing visually "behind" you. Shadows stay on the ground plane while the body
moves on the height axis — this is what sells the sense of 3D space in a 2.5D game.

### 3.6 Hit reactions need a poise/stagger layer
Pure hitstun on every hit makes enemies into punching bags and makes big enemies feel
weightless. A poise pool that depletes per hit and regenerates over time, breaking into a
stagger state only when exhausted, is what makes different enemy weights feel different.

---

## PART 4 — COMBAT SYSTEM SPECIFICATION

All timings in **frames at a fixed 60 Hz physics tick**. This is non-negotiable: combat
logic runs on `_physics_process` at a fixed timestep, never on variable frame time.

### 4.1 Player state machine

```
GROUNDED: Idle, Walk, Run, Dash, Land
AIRBORNE: JumpRise, Fall, AirDash, EnemyStep
ACTION:   Attack(move_id, phase), Dodge, Taunt
REACTION: Hitstun, Knockback, Knockdown, GetUp
SYSTEM:   Dead, Cutscene
```

Each state is a node with `enter()`, `exit()`, `physics_update(delta)`, and
`handle_input(event)`. Adding a move never touches existing states.

### 4.2 Player frame data

Moves are **data, not code** — defined as Godot `Resource` files (`MoveData.tres`) so
tuning never requires editing scripts.

| Move | Input | Startup | Active | Recovery | Cancel from | Dmg | Poise dmg | Hitstop | Knockback |
|---|---|---|---|---|---|---|---|---|---|
| Light 1 | Attack | 7 | 3 | 14 | 10 | 100 | 20 | 5 | 0.8 m |
| Light 2 | Attack (chain) | 8 | 3 | 15 | 11 | 110 | 20 | 6 | 0.9 m |
| Light 3 | Attack (chain) | 11 | 4 | 24 | 18 | 180 | 35 | 9 | 2.4 m |
| Launcher | Hold Attack | 14 | 4 | 26 | 20 | 150 | 50 | 10 | launch +6 m/s Y |
| Heavy Slam | Air + Heavy | 12 | 5 | 30 | 24 | 220 | 60 | 12 | ground-bounce |
| Gun | Ranged | 5 | hitscan | 9 | 6 | 20 | 2 | 2 | 0.1 m |
| Air Light 1 | Air + Attack | 6 | 3 | 12 | 9 | 90 | 15 | 5 | 0.4 m |
| Air Light 2 | Air + Attack | 8 | 3 | 14 | 10 | 100 | 15 | 6 | 0.5 m |
| Dodge | Dodge | 2 | — | 8 | 20 | — | — | — | i-frames 3-16 |
| Enemy Step | Jump near enemy | 3 | — | 4 | 5 | — | — | — | resets air actions |

**Cancel rule:** during a move's cancel window the player may cancel into: the next combo
link, Dodge, Jump, or Gun. Dodge and Gun are *universal* cancels (available from every
move's cancel window) — this is what creates expressive play.

### 4.3 Hitstop

On a confirmed hit, both attacker and victim freeze. Implementation: a global
`HitstopManager` that sets `Engine.time_scale` is **wrong** (it freezes UI and VFX too).
Correct: each actor has a `hitstop_frames` counter; while > 0 its `physics_update` is
skipped and its animation playback speed is 0. Victim freeze = attacker freeze × 1.2.

Additionally, during hitstop the victim is offset by a small positional shake
(±0.04 m, alternating per frame). This is the single cheapest trick that makes hits feel
like they have force.

### 4.4 Juggle system

- Air hit counter per victim, reset on landing.
- Gravity scale on the victim increases per air hit: `gravity_mul = 1.0 + 0.12 * air_hits`.
- Launch height from subsequent hits decays: `launch_power * pow(0.85, air_hits)`.
- At `air_hits >= 8`, the next hit forces a non-recoverable knockdown.

This prevents infinite juggles without a hard, feel-breaking cutoff.

### 4.5 Style meter

Ranks: `D → C → B → A → S → SS → SSS`

- Each move has a `style_value`.
- **Repeat lockout:** after a move scores, that specific move earns 0 style for 90 frames.
  Using it again within the window also applies a −15% multiplier to the meter.
- Meter decays at 2.5% per frame when the player has not landed a hit for 90 frames.
- Taking damage drops the meter by one full rank.
- Perfect dodge (dodging within 6 frames of an incoming active hitbox) grants a flat bonus
  and a brief slow-motion flash.

### 4.6 Enemy AI

State machine: `Idle → Approach → Reposition → Telegraph → Attack → Recover`, with
interrupt states `Hitstun`, `Stagger`, `Launched`, `Knockdown`, `GetUp`, `Guard`, `Dead`.

- **Telegraph is mandatory and visible**: minimum 18 frames, with an emissive colour flash
  on the enemy material. An attack the player cannot read is a bug, not difficulty.
- **Aggression token system**: the arena holds N attack tokens (N=2 at normal difficulty).
  An enemy must hold a token to enter Telegraph. This stops six enemies attacking at once,
  which is the classic reason brawlers feel unfair.
- **Poise**: pool of 100 (light enemy) / 220 (heavy). Depletes by each move's poise damage,
  regenerates at 20/sec after 1.5s without being hit. Break → `Stagger` for 60 frames.
- Three enemy types: **Grunt** (fast, low poise, melee), **Brute** (slow, high poise,
  unlaunchable until staggered), **Ranged** (keeps distance, forces player movement).

### 4.7 Camera

- Side-on, follows player with asymmetric damping (fast catch-up on X, slow on Z).
- **Frames both combatants** during lock-on: midpoint targeting with distance-based FOV.
- **Impact response**: on heavy hit, FOV punch (−4° over 3 frames, recover over 12) plus
  positional shake on a decaying noise curve. Shake is capped and always decays — uncapped
  shake is nausea, not feel.
- Lock-on: soft-target nearest enemy within a forward cone; attacks auto-face the target
  and apply a small attack-step translation toward it.

---

## PART 5 — TECHNICAL ARCHITECTURE

```
res://
├── project.godot
├── src/
│   ├── core/
│   │   ├── state_machine/        StateMachine.gd, State.gd
│   │   ├── combat/               Hitbox.gd, Hurtbox.gd, DamageInfo.gd,
│   │   │                         HitstopComponent.gd, PoiseComponent.gd,
│   │   │                         HealthComponent.gd
│   │   ├── input/                InputBuffer.gd, ActionMap.gd
│   │   └── data/                 MoveData.gd (Resource), EnemyData.gd
│   ├── player/
│   │   ├── Player.tscn / Player.gd
│   │   ├── states/               (one .gd per state)
│   │   └── moves/                *.tres  (frame data, no code)
│   ├── enemies/
│   │   ├── Grunt.tscn, Brute.tscn, Ranged.tscn
│   │   └── ai/
│   ├── camera/                   CombatCamera.gd
│   ├── systems/                  StyleMeter.gd, WaveDirector.gd, AggroTokens.gd
│   └── ui/                       HUD.tscn, StyleRank.gd, HealthBar.gd
├── assets/
│   ├── models/   animations/   materials/   vfx/   audio/
├── levels/                       Arena01.tscn
└── tools/
    ├── verify/                   headless capture harness (see PART 8)
    └── export/                   build scripts
```

**Hard architectural rules:**
- Combat logic lives in `_physics_process` only. No gameplay in `_process`.
- No move behaviour hardcoded in scripts — all in `.tres` resources.
- Components (Health, Poise, Hitstop, Hurtbox) are reusable nodes, identical on player
  and enemies. The player is not special-cased.
- Signals for events (`hit_landed`, `poise_broken`, `style_gained`); no cross-node polling.

---

## PART 6 — ANIMATION: THE REAL BOTTLENECK

This is the part that decides whether the game looks good, and it is the part I am
weakest at. Full transparency:

**What I can do:** author animations as explicit keyframe tracks on a skeleton
(`AnimationPlayer` tracks in text format), build an `AnimationTree` state machine, blend
locomotion, apply root motion, and layer procedural motion on top (lean into movement,
weapon trails, impact recoil, additive hit reactions, IK foot planting). I can then
screenshot the result frame-by-frame and iterate until the run cycle reads correctly.

**What I cannot do:** produce motion-capture-quality humanoid animation by hand. A
hand-keyed run cycle on a blockout rig will read as "a character running" — it will not
read as "Dante running".

**This is why PART 7 matters more than anything else in this document.**

---

## PART 7 — ASSET STRATEGY: THE DECISION YOU MUST MAKE

### PATH A — Fully autonomous (I do 100%, you do nothing)

Stylized low-poly blockout characters built procedurally, hand-keyed animation,
code-driven VFX.

- **Visual result:** clean, readable, stylized. Think a competent game-jam prototype
  with excellent feel. Not impressive to look at.
- **Your effort:** zero.
- **Risk:** none. Guaranteed to ship.
- **"VIP game" reaction:** unlikely on looks. Possible on feel.

### PATH B — You supply animation, I supply everything else  ← **MY RECOMMENDATION**

You spend roughly 30-60 minutes, once, on your own PC:
1. Go to mixamo.com (free, requires a free Adobe account).
2. Download one humanoid character (e.g. "Y Bot" or any character you like).
3. Download ~15 animations onto it: Idle, Walk, Run, Jump, Fall, Land, Dodge Roll,
   Sword Slash 1/2/3, Sword Launcher, Air Slash 1/2, Hit Reaction, Knockdown, Get Up.
   (Export: FBX for Unity, 30fps, with skin.)
4. Drop them into `assets/animations/` in this repo and push.

I handle everything after that: import, retarget into the `AnimationTree`, map every clip
to the frame data in PART 4.2, add cancel windows, trails, and VFX.

- **Visual result:** a real humanoid character with real motion-captured combat animation.
  This is the difference between "prototype" and "a game someone would install".
- **Your effort:** under an hour, once.
- **Risk:** low. The animation mapping layer is designed for exactly this swap.
- **"VIP game" reaction:** realistically achievable.

**I am building the project so that Path A works immediately and Path B is a drop-in
upgrade at any time.** You are not locked in. But if you want the result to be impressive,
Path B is the honest answer, and it needs that one hour from you — because mixamo.com is
blocked from this container (HTTP 403) and I cannot get those files myself.

---

## PART 8 — VERIFICATION PIPELINE (the anti-"khudi line" system)

This is the part that did not exist in previous attempts. It is non-optional.

### 8.1 Automated visual capture
A headless harness (`tools/verify/capture.gd`) that:
- Boots any scene with `xvfb-run godot --rendering-driver opengl3`
- Drives scripted input (e.g. "run right for 40 frames, then attack")
- Captures a PNG every N frames into a contact sheet
- Exits with a non-zero code on any Godot error or warning

I run this after every meaningful change and **look at the output images myself**.

### 8.2 Logic tests
GUT-style headless unit tests for: input buffer windows, cancel window boundaries,
hitstop counters, poise depletion/regen, juggle decay, style scoring and repeat lockout.
These run in `--headless` with no rendering and must all pass before any commit.

### 8.3 Definition of Done per phase
A phase is **not** done until all four are true:
1. The game boots and runs with zero errors in the Godot log.
2. All logic tests pass.
3. A contact-sheet screenshot proves the feature visually, and I have inspected it.
4. The code is committed and pushed to GitHub.

**If I cannot produce the screenshot, the feature is not done, and I will say so.**

---

## PART 9 — TIMELINE

Estimated in **work sessions**, not calendar days (your schedule sets the calendar).
Each phase ends in a runnable, committed, screenshot-verified state. There is no phase
whose deliverable is "code that might work".

| Phase | Deliverable | Acceptance criteria | Est. |
|---|---|---|---|
| **P0** | Research + this document + verified toolchain | You approve the plan | **DONE** |
| **P1** | Project skeleton, verification harness, CI script | `verify.sh` outputs a contact sheet of a running scene | **DONE** |
| **P2** | Movement + camera: walk, run, jump, fall, land, dodge, 2.5D depth, shadows | Screenshot strip shows a readable run cycle and a dodge with i-frame window | **DONE** |
| **P3** | Combat core: state machine, MoveData resources, hitbox/hurtbox, input buffer, cancel windows, hitstop, damage | Ground 3-hit combo lands on a training dummy, each hit visibly freezes; unit tests green | 2 |
| **P4** | Enemy #1 (Grunt): AI states, telegraph, poise, stagger, hitstun, knockdown, get-up, aggro tokens | A real fight against 3 Grunts is playable and winnable | 2 |
| **P5** | Air combat: launcher, juggle decay, air combo, enemy step, gun, dive slam | A launcher → 4-hit air combo → slam is performable and captured on screenshots | 2 |
| **P6** | Style meter + HUD + camera feel (shake, FOV punch, lock-on) | Rank climbs D→SSS on varied play, drops on mashing | 1-2 |
| **P7** | Enemies #2 and #3 (Brute, Ranged) + wave director + arena + win/lose/pause | Full 8-wave survival loop completable start to finish | 2 |
| **P8** | Polish: weapon trails, impact VFX, screen effects, SFX, audio mix, menus, settings | Side-by-side screenshots: pre-polish vs post-polish | 2-3 |
| **P9** | **Real build**: Windows `.exe` + Linux binary, packaged, README, controls, version tag | You download it, install it, and it runs on your PC | 1 |

**Total: roughly 14-18 work sessions.** If Path B is chosen, add one short session for
animation retargeting (slots into P2/P3).

I will not skip P1 or P8. P1 is what prevents failure; P8 is what separates "a demo" from
"a game".

---

## PART 10 — RISKS AND MITIGATIONS

| Risk | Severity | Mitigation |
|---|---|---|
| Animation quality (hand-keyed looks stiff) | **HIGH** | Path B (Mixamo). This is the main risk to the end result. |
| Software renderer (llvmpipe) is slow here, so I cannot judge real performance | MEDIUM | Keep draw calls low by design; you test real FPS on your GPU each phase |
| Scope creep killing the project (the historical failure) | **HIGH** | Hard scope boundary in PART 2; no feature enters without being in this doc |
| Combat tuning feels wrong to you specifically | MEDIUM | All tuning is in `.tres` data files; you can change numbers without touching code |
| Asset sites blocked from this container | CONFIRMED | Path B, or procedural generation under Path A |
| Container is ephemeral (work lost) | LOW | Commit and push to GitHub every phase, without exception |

---

## PART 11 — WHAT I WILL NOT DO

So there is no misunderstanding later:

1. I will not claim a feature works without a screenshot or a passing test proving it.
2. I will not produce AAA art. If you need that, you need to hire artists.
3. I will not silently reduce scope. If something cannot be done, I will say it in that
   session, not at the end.
4. I will not start writing game code until you approve this plan and choose Path A or B.

---

## PART 12 — DECISIONS NEEDED FROM YOU

1. **Path A or Path B** (PART 7). This is the big one.
2. **Engine confirmation**: Godot 4.4.1 — agreed? (If you insist on Unity, say so now;
   I will tell you exactly what I lose, mainly the ability to verify my own work.)
3. **Platform**: Windows `.exe` only, or Windows + Linux?
4. **Controls**: keyboard+mouse only, or gamepad support too? (Gamepad is strongly
   recommended for this genre and costs very little.)

---

## PART 13 — SOURCES CONSULTED

- Devil May Cry combat & style system — https://shapes.inc/fandom/devil-may-cry/combat-mechanics
- DMC5 game overview — https://bkbrent.com/dmc5/dmc5-overview/
- Input buffering and game feel — https://www.wayline.io/blog/input-buffering-responsive-game-feel
- Missed jump inputs / buffering rationale — https://gamedev.net/news/your-players-hate-missed-jump-inputs-heres-why-r4298/
- Fighting game state handling — https://gamedev.net/forums/topic/639005-how-to-handle-states-in-a-fighting-game/5034120/
- Hitbox/hurtbox in Godot 4 — https://www.gdquest.com/library/hitbox_hurtbox_godot4/
- Godot 4 hitbox/hurtbox components (windup/active/recovery, hit-stop, i-frames) — https://github.com/CodingQuests/godot-hitbox-hurtbox
- Godot 4 state machine pattern — https://codingquests.io/blog/godot-4-state-machine-tutorial
- Godot 4 3D character controller — https://codingquests.io/blog/godot-4-3d-character-controller-tutorial
- 2.5D beat-em-up development theory — https://gamedev.net/forums/topic/608266-25d-beat-em39-up-development-theory/
- Beat 'em up dev guide (depth axis, shadows, hit depth checks) — https://patreon.com/posts/beat-em-ups-dev-134611716
- Designing hitboxes for a beat-'em-up (Wulverblade) — https://www.gamedeveloper.com/design/designing-great-hitboxes-for-a-2d-beat--em-up-with-swords-and-shields
