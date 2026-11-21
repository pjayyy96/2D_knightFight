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

---

## Milestone 3 — Boomerang shield (press **J**)

**Read**
1. `scripts/shield.gd`: the diagram at the top, then `_physics_process`. Each `State` branch
   only knows how to move and when to switch to the next state.
2. `scripts/player.gd`: `facing` (set while running), `@onready var shield`, and step 8 (throw).
3. `scenes/player.tscn`: the shield is a child of the player, but with `top_level = true`
   (in `shield.tscn`), so it moves in world space once thrown.
4. `tests/test_shield.gd`: an automatic check that steps the shield frame by frame.

**Key ideas**
- **State machine.** Rather than a pile of `if thrown and not returning and ...` flags, there is
  one `state` variable with exactly three values. Bugs like "flying and held at the same time"
  become impossible. Enemies and bosses later use the same pattern.
- **Homing return.** On the way back the shield aims at where the player is *now*, every frame
  (`move_toward`). Run away and it chases you. It also ignores walls, so it can't get stuck.
- **Area2D vs bodies.** The shield is an `Area2D`: it detects overlaps (walls now, enemies in
  milestone 5) but never pushes anything.
- **Tests.** Run the check yourself (in Git Bash, from the project folder):
  `"<path to Godot>_console.exe" --headless --path . --script tests/test_shield.gd`
  It prints `shield tests: OK`.

**Try this**
- In `shield.tscn` (select the Shield node): set `max_distance` to 300, or `return_speed` to 200.
  With a slow return, run away from it.
- Throw it at the *LeftWall* from close up. It bounces back early.
- Break the test on purpose: change `return_speed` to 0 and run the test. Read the FAIL lines,
  then put it back.

---

## Milestone 4 — Pogo (hold **S / ↓** in the air)

**Read**
1. `scripts/spikes.gd`: a hazard that kills your body, but is in the `"pogo"` group.
2. `scripts/shield.gd`: the `HELD` branch puts the shield under your feet, turned flat, when
   `player.shield_down`. `touching_pogo_target()` looks for anything in the `"pogo"` group.
3. `scripts/player.gd`: step 7 (pogo check), plus `pogo()` and `die()` at the bottom.
4. `scenes/main.tscn`: *PracticeSpikes* under LeftPlatform, and the 200 px *SpikeField* past the pit.
5. `tests/test_pogo.gd`: drops the knight on spikes twice, with and without the shield.

**Key ideas**
- **Groups = tags.** The shield doesn't know what spikes are. It only asks "is this in `pogo`?".
  Enemies and bullets (milestone 5) join the same group, and the pogo code doesn't change at all.
- **The bounce refills your double jump.** That makes chains possible: bounce, double jump, bounce...
  That chaining is the heart of this genre.
- **Order inside a frame matters.** The first version checked the bounce in the *shield*, which
  runs *after* the player moved. The test caught it: the knight bounced *and* died, because in that
  one frame the body had already dropped onto the spikes. The fix was to check *before*
  `move_and_slide()`. The shield sits 10 px below the feet and the fastest fall is about 7 px per
  frame, so the body can't reach the spikes first anymore.
- **Duck typing.** Spikes call `die()` on anything that *has* a `die()` method. They don't care
  that it's the player.

**Try this**
- Cross *SpikeField* with only pogos, then with pogo + double jump chains.
- Set `pogo_velocity` to -450 for huge bounces, or -150 for tiny ones.
- Set the shield's `down_offset` to 8 (closer to the feet) and run `test_pogo.gd`. Does it still
  pass? Why or why not? (Hint: 7 px per frame.)

---

## Milestone 5 — Enemies

Red **Walker** patrols LowPlatform. Purple **Shooter** sits near the pit and fires yellow bullets left.

| You do | Walker / Shooter | Bullet |
|---|---|---|
| Thrown shield hits it | dies | gone |
| Held shield (facing it) | – | **blocked** |
| Pogo onto it | dies, you bounce | gone, you bounce |
| Touch it with your body | you die | you die |

**Read**
1. `scripts/enemy.gd`: the shared rules. Note `class_name Enemy`.
2. `scripts/enemy_walker.gd`, `scripts/enemy_shooter.gd`, `scripts/bullet.gd`: each starts with
   `extends Enemy` and only adds what's different.
3. `scripts/player.gd` step 7: the pogo now calls `hit()` on whatever it bounced on.
4. `tests/test_enemies.gd`: builds a fresh mini-level for each case.

**Key ideas**
- **Inheritance.** `Enemy` holds the rules every hostile thing shares. `bullet.gd` *overrides* two
  functions: it also dies on walls, and *any* shield stops it, not just a flying one. `super()`
  means "also run the parent's version". Forget it in the shooter's `_ready()` and it stops
  being pogo-able, because the parent's `_ready()` is what adds it to the `"pogo"` group.
- **Raycasts as feelers.** The walker turns when its floor ray finds nothing (a ledge) or its wall
  ray finds something. After turning it re-aims at once (`force_raycast_update`). Without that,
  next frame reads the *old* side's answer, turns back, and it jitters at the edge forever.
- **Spawning.** The shooter `preload`s the bullet scene once and `instantiate()`s a new copy every
  2 s. Bullets are added to the *level*, not the shooter, so they fly on their own.
- **Reuse pays off.** The pogo code from milestone 4 didn't change at all. Enemies just joined the
  `"pogo"` group.

**Try this**
- Stand facing the Shooter and let bullets hit your shield. Then throw the shield and get hit.
- Kill the Walker by pogo from HighPlatform, and the Shooter with a throw.
- Select *Shooter* in `main.tscn` and set `fire_interval` to 0.5. Can you pogo across the bullet stream?
- Delete `super()` in `enemy_shooter.gd`, run, and try to pogo the Shooter. Then put it back.

---

## Milestone 6 — Health, mana, gold

The top-left line shows `HP 3/3  MANA 4/4  GOLD 0`.

| Event | Effect |
|---|---|
| Throw the shield | −1 mana (no mana = no throw) |
| Pogo an enemy or bullet | +1 mana |
| Kill an enemy | +1 gold (bullets pay nothing) |
| Body touches enemy, bullet or spikes | −1 HP, knocked away, 1 s flicker (can't be hurt) |
| HP hits 0, or fall in the pit | back to start, HP and mana full, **gold kept** |

**Read**
1. `scripts/game_state.gd` and the `[autoload]` section in `project.godot`.
2. `scripts/hud.gd` and the *HUD* node at the bottom of `main.tscn`.
3. `scripts/player.gd`: the *Combat* exports, step 9 (paying for throws), step 10 (flicker),
   and `take_hit()` / `die()`.
4. `scripts/enemy.gd` `hit()`: pays gold, but never twice.

**Key ideas**
- **Autoload = global singleton.** One `GameState` node lives above every level, so any
  script can read or change `GameState.gold`. Keep it small: only data that must outlive a
  scene belongs there.
- **Signals decouple.** `GameState` doesn't know the HUD exists. It just announces `changed`,
  and whoever cares listens. A sound effect or a shop could listen to the same signal later.
- **The core loop is now real.** Throwing costs mana, and only pogo kills give it back. Playing
  safe on the ground runs you dry, so the game *pushes* you into the air.
- **Invincibility frames** stop one hit from draining all your HP in a quarter second. The flicker
  tells the player "you're safe for a moment".
- **Signal vs per-frame check.** `body_entered` only fires on *entering*. Spikes now check every
  frame instead, otherwise landing in them while flickering would make you immune forever.
  Enemies still use the signal (see the `shortcut:` comment in `enemy.gd`).
- **Testing autoloads.** Tests reach GameState as `gs` and `load()` scenes at runtime. The note
  at the top of `test_enemies.gd` explains why.

**Try this**
- Throw 4 times without pogoing. Then refill by bouncing on the Walker or on bullets.
- Set `MAX_HP` to 1 in `game_state.gd` for "one hit = death" mode.
- Set the player's `invincible_time` to 0 and stand in the spikes. Count how fast you die.
