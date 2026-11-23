# Learning log — 2D Knight Fight

An original 2D platformer in Godot 4. Each milestone adds one mechanic. Read the
files listed, run the game (F5), then try the tweaks.

Controls: **A/D or ←/→** move · **Space / W / ↑** jump · **J** throw shield (milestone 3) · **S / ↓** shield down (milestone 4) · **K** hold to heal (milestone 12) · **L / Shift** air dash (milestone 13)

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

---

## Milestone 7 — Checkpoints

Two flags: **CheckpointA** before the Shooter, **CheckpointB** at the far end past the spike
field. Stand at one **on the ground** and press **S / ↓** to pay 1 gold. The flag turns green,
your HP and mana refill, and from now on dying brings you back there.

**Read**
1. `scripts/checkpoint.gd`: the whole feature in ~40 lines.
2. `scripts/game_state.gd`: `spend_gold()` is the same "pay, or refuse and pay nothing" pattern
   as `spend_mana()`.
3. `scripts/player.gd`: `_ready()` joins the `"player"` group, and `die()` uses `spawn_point`.
4. `tests/test_checkpoint.gd`: five cases, from "too far away" to "don't charge twice".

**Key ideas**
- **One variable does the work.** Respawning already used `spawn_point`. A checkpoint just
  *overwrites* it. Good earlier design makes later features small.
- **Reusing a key by context.** S in the air = shield down. S on the ground at a flag = save.
  Fewer keys to learn, and no new input action needed.
- **Gold as a decision.** Saving costs the same gold you'll want for upgrades later. That
  trade-off is what makes a currency interesting.
- **Feedback.** Without enough gold the label changes to "need 1g". Silence would feel like a bug.

**Try this**
- Kill the Walker (1 gold), light CheckpointA, then die on purpose. Where do you come back?
- Set CheckpointB's `cost` to 0 in the Inspector (select it in `main.tscn`).
- In `checkpoint.gd`, remove the `body.is_on_floor()` check. Now you can save in mid-air while
  pogoing past the flag. Is that better or worse?

---

## Milestone 8 — Slide & long jump

New section past CheckpointB: double-jump onto the **Plateau**, then hold **S / ↓** on the
**Hill** to slide down on your shield, and jump at the bottom. The gap after it is **150 px**.
A running double jump only covers ~120 px, but a slide jump carries ~180 px.

**Read**
1. `scripts/slope.gd`: a ramp is a `CollisionPolygon2D` triangle instead of a rectangle.
2. `scripts/player.gd`: the *Sliding* exports, `floor_snap_length` in `_ready()`, and step 6,
   now split into **6a slide / 6b coast / 6c run**.
3. `tests/test_slide.gd`: no slip when idle, slide speed, long jump, braking.

**Key ideas**
- **The floor normal.** `get_floor_normal()` is the arrow pointing out of the ground. On a slope it
  leans downhill, so `signf(normal.x)` *is* the downhill direction. No angle math needed.
- **Momentum = "don't cap the speed".** Running can never exceed `run_speed`, so any extra speed
  must come from a slide. Branch 6b lets that extra fade slowly (`momentum_drag`) instead of
  snapping back. Jump during it and the speed comes along. That's the whole "long jump" feature.
  Holding the opposite direction skips 6b, so braking still feels normal.
- **Floor snapping.** At 280 px/s down a slope you move sideways faster than gravity pulls you
  down, so you'd lift off every frame. `floor_snap_length` pulls you back onto the surface.
- **Design with numbers.** The gap was first 200 px. A simulated run showed *neither* jump made it
  (slide ~180, run ~120), so it became 150 px, which has a clear margin both ways. Measure, don't guess.

**Try this**
- Jump the gap without sliding. Then with a slide. Feel the difference.
- Set `momentum_drag` to 0 (speed never fades) or 600 (fades almost at once), then retry the gap.
- In `main.tscn`, make the *Hill* steeper: `size = Vector2(80, 60)`. Is it still slideable? Try
  `Vector2(50, 60)` (steeper than 45°) and see it turn into a wall.
- Slide down the Hill and over spikes: sliding counts as shield-down, so it pogo-protects you.

---

## Milestone 9 — Boss

*(Built in parallel by a helper agent while milestone 7 was made.)*

Open `scenes/boss_arena.tscn` and press **F6** (runs just this scene). Green block, 6 HP, bar above it.

| Boss does | You do |
|---|---|
| Winds up (stands still 1 s) | get ready; hit it now if you're close |
| Charges to the far wall | jump over it (it's 32 px tall, a jump is 60), pogo it on the way |
| Dazed at the wall | throw the shield or pogo it |
| Fires 3 bullets back | jump them, or block with the held shield |
| **Phase 2** (orange, below half HP) | same fight 1.6× faster; every other bullet flies HIGH, so stay down for those |

**Read**
1. `scripts/boss.gd`: the diagram at the top, then `_physics_process`. Same state-machine idea as
   `shield.gd`, with four states and one shared `_timer`.
2. `hit()` in `boss.gd`, next to `hit()` in `enemy.gd`: the boss overrides it to lose HP, and only
   calls `super()` (pay gold, vanish) on the last hit.
3. `scenes/boss_arena.tscn`: a test arena with its own HUD. Note the `Camera2D` override at the
   bottom: limits keep the whole arena on screen.
4. `tests/test_boss.gd`: case 2 throws a real shield through the boss.

**Key ideas**
- **Override + `super()`.** The boss reuses Enemy's contact damage, pogo group and gold payout.
  It only changes *when* it dies.
- **Invulnerability window.** A thrown shield passes through the boss twice (out and back).
  The throw lasts 0.72 s, so hits are ignored for 0.75 s afterwards. The flicker shows it.
  The first try used 0.6 s; the test caught a close throw hitting twice.
- **Phases with one number.** Phase 2 multiplies `delta` by `rage`. Movement gets faster *and*
  every timer runs out sooner, with no second copy of each setting.
- **Fair attacks.** Every attack has an answer: wind-up = warning, charge = jump/pogo,
  daze = punish, low bullet = jump/block, high bullet = stay down. A boss is a test of the
  moves you already learned.
- **Signals for later.** `defeated` is emitted but nothing listens yet. The world map will.

**Try this**
- Select *Boss* in the arena: set `rage` to 2.5 for a brutal phase 2, or `max_hp` to 2 to test the end quickly.
- Set `hit_cooldown` to 0.3 and run `test_boss.gd`. Read which check fails and why.
- Set `shots` to 6 and `shot_interval` to 0.25 for a bullet wall. Is it still fair?
- Beat it without throwing once (pogo only), then without pogoing once (throws only).

---

## Milestone 10 — World map

*(Built in parallel by a helper agent while milestone 8 was made.)*

The game now starts on a **map**. A/D (or ←/→) walks the knight between levels, Space enters one.
Grey = locked, gold = open, green = done. Beat a level (walk into the yellow **EXIT** gate at the
very end of level 1, past the slide gap, or defeat the boss) and you return to the map with the
next level open. Progress and gold are saved, so they're still there after you quit.

**Read**
1. `scripts/world_map.gd`: the `LEVELS` list at the top, then `move_cursor()`, `enter_level()` and
   `_draw()`. The whole map is drawn from that list plus GameState.
2. `scripts/game_state.gd`: the bottom half. `unlocked`, `complete_level()`, `finish_level()`,
   `save_game()` / `load_game()`.
3. `scripts/level_exit.gd` and `scripts/boss_arena.gd`: two different "you won" triggers that
   both end in the same `GameState.finish_level(id)`.
4. `tests/test_world_map.gd`: plays map → level → win → map, saving to a temp file.

**Key ideas**
- **One number can be the whole save.** Levels are played in order, so "highest unlocked level"
  also tells you which ones are beaten. Simple data = simple save file. (A branching map would
  need a list of beaten levels instead; see the `shortcut:` comment.)
- **Data, not hand-placed nodes.** The map draws itself from `LEVELS`. Adding level 3 is one line,
  and the picture can never disagree with the save.
- **ConfigFile** writes `[section]` and `key=value` text, the same format as `project.godot`.
  `user://` is a per-game folder Godot picks (on Windows: `%APPDATA%\Godot\app_userdata\2D Knight Fight`).
  Open `save.cfg` in Notepad after beating level 1.
- **Don't trust files.** `load_game()` wraps values in `int()` and keeps the starting values when
  there's no save yet. A missing or hand-edited file must not crash the game.
- **Who survives a scene change?** `change_scene_to_file` throws the current level away. The
  "wait, then go back to the map" countdown lives in GameState, the autoload, which stays.
- **Signals pay off.** The boss has emitted `defeated` since milestone 9. Now a 10-line arena
  script listens to it, and `boss.gd` didn't change.
- **Tests must not touch your real data.** `save_path` is a variable, so the test points it at a
  temp file and deletes it at the end.

**Try this**
- Beat level 1, quit, start again. Then delete `save.cfg` from the folder above and start once more.
- Add a third line to `LEVELS` that points at `res://scenes/main.tscn` again. Watch it appear
  locked, then open after the boss.
- Set `WIN_DELAY` to 0 in `game_state.gd`. Does the win still feel like a win?
- In `world_map.gd`, delete `or not GameState.is_unlocked(next + 1)` and run `test_world_map.gd`.
  Read the FAIL line, then put it back.

**Known limits**
- Gold is saved only when you finish a level. Quit mid-level and that level's gold is lost.
- Running a level directly with F6 skips the save (gold starts at 0). That's handy for testing.
- During the 1.5 s win pause the game keeps running. You can still get hit, but the win is already saved.

---

## Milestone 11 — Stomp

Jump on an enemy's **head** (no shield needed): it dies and you bounce, but you get **no mana**.
Only the shield pogo refuels you, so stomping is the easy move and the pogo is the skilled
one that pays. Walking into an enemy from the side still hurts. Bullets always hurt your body
(only the *shield* can pogo them). The **boss** loses 1 HP per stomp, and its HP bar now
**slides** down instead of jumping.

**Read**
1. `scripts/enemy.gd`: `_on_body_entered()` and `_is_stomp()`. Every enemy decides "stomped or
   rammed?" in one place, so walker, shooter and boss all got stomping at once.
2. `scripts/player.gd`: `bounce_on()`, shared by the pogo (step 7) and the stomp.
3. `scripts/bullet.gd`: overrides `_on_body_entered()` so bullets *can't* be stomped.
4. `scripts/boss.gd` `hit()`: `create_tween()` slides the bar.
5. `scripts/enemy_walker.gd`: the wall-feeler now ignores the player (see below).

**Key ideas**
- **Top vs side, with two numbers.** A stomp = the player is *falling* (`velocity.y > 0`) and their
  center is *above* the enemy's. Standing on the floor, `velocity.y` is 0, so walking into an enemy
  is never a stomp.
- **One function, two features.** Pogo and stomp both call `bounce_on(target)`; the stomp passes
  `give_mana = false`. A default parameter (`give_mana := true`) lets one caller opt out
  without touching the others. A change to
  "what happens when you bounce" (sound, effects) now lands in both automatically.
- **Tweens** animate a value over time: `tween_property(hp_bar, "value", hp, 0.4)` means
  "slide the bar to hp in 0.4 s". The same tool works for fades, flashes and moving platforms.
- **New tests find old bugs.** The "side contact hurts" test failed at first: the walker's
  wall-feeler also saw the *player* and turned away before touching you. Walkers had been
  harmless from the side since milestone 5. Now only real walls (`StaticBody2D`) turn them,
  same as the boss.

**Try this**
- Stomp the Walker, then the Shooter, and watch MANA stay put. Pogo the next one: +1.
  Then try stomping a bullet (ouch).
- Stomp the boss 6 times. Watch the bar slide, and notice every second quick bounce is
  ignored (the hit cooldown from milestone 9).
- In `boss.gd`, change the tween time `0.4` to `2.0` for a slow, dramatic bar.
- In `enemy.gd` `_is_stomp()`, remove `body.velocity.y > 0.0 and`. Then jump *up* into an enemy
  from below. Why does that now count as a stomp, and why is that wrong?

---

## Milestone 12 — Heal (hold **K**)

Stand still on the ground and **hold K**. Your knight slowly turns green; after 0.8 s you get
**+1 HP for 2 mana**. Keep holding to heal again. Move, jump, let go, or get hit, and the charge
starts over. It does nothing at full HP or with less than 2 mana (so it never wastes mana).

**Read**
1. `scripts/player.gd` step **9b**: the whole move is one `if` with a timer.
2. `scripts/player.gd` `take_hit()`: one line, `heal_timer = 0.0`, makes hits cancel a heal.
3. `scripts/game_state.gd` `heal()`: the same "never past the max" pattern as `add_mana()`.
4. `tests/test_heal.gd`: seven cases, one per rule above.

**Key ideas**
- **Mana is now a choice.** Before, mana only meant "throws left". Now 2 mana = 2 throws *or*
  1 HP. Do you attack, or save up to survive? That one decision makes the resource interesting,
  and it's also why pogo kills (the only refill) matter even more.
- **A charge time is a price you pay in danger, not in mana.** For 0.8 s you can't move or fight.
  Heal next to an enemy and it interrupts you. So players learn to clear an area first, then heal.
- **Hold-to-charge = a timer that resets.** `heal_timer += delta` while *every* condition holds,
  `heal_timer = 0.0` the moment *any* breaks. You'll see this pattern for charged attacks, bows,
  and "hold to open" doors.
- **`lerp` shows hidden state.** `body_color.lerp(heal_color, heal_timer / heal_time)` blends
  from blue (0.0) to green (1.0). The timer is invisible; the color tells the player "almost there".
- **`can_heal` checks the mana *before* charging.** Otherwise you'd sit green for 0.8 s and then
  get nothing. Check early, so the player never pays (in time) for something that can't happen.
  Same rule as the throw in step 9: check the hand first, then pay.

**Try this**
- Take a hit from the Shooter, walk away from it, and heal. Then try healing right next to it.
- In the Inspector (select Player in `main.tscn`), set **Heal Time** to `0.3`. Too easy? Set **Heal
  Cost** to `1`. Which change makes the game easiest, and which one breaks the "mana is a choice" idea?
- Remove `dir == 0.0 and` from `can_heal`. Now you can heal while running. Why does that make the
  charge time almost pointless?
- Give the heal its own sound or particle burst at the moment `GameState.heal(1)` runs.

---

## Milestone 13 — Air dash (**L** or **Shift**)

In the air, press **L** (or **Shift**) for a short, flat burst sideways: about 57 px in 0.15 s,
with no falling. Hold ←/→ to pick the direction (otherwise you dash the way you face).
One dash per jump. **Landing or a pogo gives it back.** Jump during the dash (double jump)
and you keep the dash speed: a dash-jump.

**Read**
1. `scripts/player.gd` step **6d**: start the dash, then hold the velocity flat until the timer runs out.
2. `scripts/player.gd` step **2** and `pogo()`: `can_dash = true`, the two refills.
3. `tests/test_dash.gd`: seven cases, one per rule above.

**Key ideas**
- **Overwrite, don't untangle.** Steps 1-6 compute gravity and running as usual. Step 6d runs
  *after* them and just replaces the velocity. A new move that "takes over" the body is often
  easiest written last, so it wins.
- **A resource that refills on skill.** Like air jumps, the dash comes back on a pogo. Now one
  pogo buys a double jump *and* a dash, so chaining bounces across a spike pit becomes a combo.
- **End states matter.** When the dash ends we drop to `run_speed`. Without that line, step 6b
  ("faster than running? keep coasting") would carry 380 px/s for ages. A move that's fine for
  0.15 s can feel broken in the frames *after* it.
- **Tests catch timing bugs.** The first version cancelled itself: dashing while still rising
  meant `velocity.y < 0`, which the code read as "a jump ended the dash". Zeroing `velocity.y`
  at the start fixed it. And in the test, a key held for 1 frame was sometimes missed, so it holds 2.

**Try this**
- Jump over the spike pit, pogo a spike, dash, double jump. How far can you chain?
- In the Inspector (Player), set **Dash Speed** to `600` and **Dash Time** to `0.1`. Same distance,
  different feel. Which one reads better?
- Remove `and not is_on_floor()` from the dash start. Ground dashes now work. Why would you then
  also want a cooldown?
- Delete the line `velocity.x = facing * run_speed` (end of the dash). Dash on flat ground, then
  in the air. Notice the long coast, and which step causes it.
