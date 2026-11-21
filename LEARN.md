# Learning log — 2D Knight Fight

An original 2D platformer in Godot 4. Each milestone adds one mechanic. Read the
files listed, run the game (F5), then try the tweaks.

Controls: **A/D or ←/→** move · **Space / W / ↑** jump · **J** throw shield (milestone 3) · **S / ↓** shield down (milestone 4)

---

## Milestone 1 — Move & jump

**Read, in this order**
1. `project.godot`: the `[input]` section names the actions (`move_left`, `jump`, …). Code asks
   about *actions*, never raw keys, so you can rebind keys later in *Project → Project Settings → Input Map*.
2. `scenes/player.tscn`: a `CharacterBody2D` (a body *you* move from code) with a collision box,
   a blue `ColorRect` as placeholder art and a `Camera2D` that follows it.
3. `scripts/player.gd`: the whole movement model. `_physics_process` runs 60×/s and does 7 steps:
   gravity → coyote timer → jump buffer → jump → jump cut → run → `move_and_slide()`.
4. `scripts/platform.gd` + `scenes/main.tscn`: the level is made of blocks. Select one in the editor
   and change **Size** in the Inspector.

**Key ideas**
- **Velocity, not position.** We change `velocity`, and `move_and_slide()` turns it into movement,
  stopping at walls and floors. Multiplying by `delta` (seconds per frame) keeps speed the same at any FPS.
- **Coyote time.** You can still jump for 0.1 s after running off a ledge. Without it, players feel
  the game "ate" their jump.
- **Jump buffer.** Pressing jump up to 0.1 s *before* landing still jumps.
- **Variable height.** A tap is a short hop, holding gives a full jump (`jump_cut`).

**Try this**
- Select *Player* in `main.tscn` → Inspector → change `gravity` to 500 (floaty) or 1500 (heavy).
- Set `coyote_time` to 0, then walk off a ledge and jump late. Notice how unfair it feels.
- Set `acceleration` and `friction` to 99999 for instant "NES-style" movement and compare.
- Add a new platform: duplicate *LowPlatform* (Ctrl+D), move it, and change its size.

---

## Milestone 2 — Double jump

**Read**
- `scripts/player.gd`: search for `air_jumps`. It's one counter, `air_jumps_left`, refilled in
  step 2 (on the floor) and spent in step 4b.
- `scenes/main.tscn`: the golden **SkyLedge** high above. Reach it from *HighPlatform*: a single
  jump rises about 60 px and a double about 120 px, and the ledge is 80 px up.

**Key ideas**
- **A resource you refill.** Jumps work like ammo: the floor reloads them. In milestone 4 the
  *pogo* bounce will also reload them, so you can chain bounces across enemies without touching
  the ground. That chaining is the core of this kind of game.
- **`if` / `elif` order.** The ground jump (with coyote time) is checked first. Walking off a
  ledge and jumping late still counts as a *ground* jump, so you keep your air jump.
- **Height math.** Jump height = v² / (2·g) = 330² / (2·900) ≈ 60 px. Change one of them and
  you can predict the new height before testing.

**Try this**
- Set `air_jumps` to 2 (triple jump) or 0 (no double jump), and try reaching SkyLedge.
- Walk off a ledge, wait about half a second, and jump twice. Count the jumps you get.
- Move SkyLedge higher, to y = -130, and work out with the formula whether it's still reachable.
