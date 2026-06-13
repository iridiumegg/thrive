# Thrive

An original 2D top-down survival & crafting game built with **Godot 4.3 + typed
GDScript**. It blends a cozy seasonal gathering/building loop with a harsh,
simulation-driven vitals model and a deep, data-driven crafting tree — all
original expression, no cloned content.

## Running

Open the project in Godot 4.3+ (or run from the CLI):

```sh
godot --path .
```

### Controls (current debug build)

| Input | Action |
|-------|--------|
| WASD / arrows | Move |
| F1 | Eat (debug, until food items exist) |
| F2 | Drink (debug) |
| F3 | Toggle sleep (time accelerates while asleep) |
| F4 | Toggle campfire warmth (debug, until placeable fires exist) |
| F5 | Cycle simulation speed ×1 / ×8 / ×32 |
| R | Restart after death |

## Tests

The simulation layer (vitals, clock, temperature, RNG) is pure logic and runs
headless:

```sh
godot --headless --path . --import   # one-time, builds the script class cache
godot --headless --path . -s tests/run_tests.gd
```

There is also an end-to-end smoke test that boots the real game headless and
fast-forwards an idle survivor until they (deterministically) perish:

```sh
godot --headless --path . -- --smoke-test
```

## Architecture

- **Fixed-step simulation:** 1 tick = 1 in-game minute. A full day/night cycle
  is 20 real minutes (locked, but exposed in `game/data/balance.json`).
- **Event bus:** systems communicate via `EventBus` signals
  (`sim_minute`, `vitals_changed`, `affliction_started`, …) and stay decoupled.
- **Data-driven everything:** all rates, thresholds, and affliction definitions
  live in `game/data/*.json`. Zero hardcoded balance numbers in code.
- **Engine-agnostic simulation:** `game/systems/vitals/*` and `game/core/game_clock.gd`
  are pure `RefCounted` logic — no nodes, no rendering — so they run headless
  and are unit-tested in `/tests`.
- **Deterministic RNG:** one root seed derives independent named streams
  (`game/core/rng_service.gd`) for reproducible worlds.

```
/game
  /core        # event bus, fixed-step sim driver, clock, RNG, balance loader
  /entities    # player
  /systems     # vitals simulation (pure logic) + engine-side adapter
  /world       # main scene, terrain generation
  /ui          # debug HUD, vitals HUD
  /data        # balance.json, afflictions.json (all tunables live here)
  /assets      # (empty — current art is generated in code; see ASSETS_LICENSES.md)
/tests         # headless unit tests for the simulation layer
```

### The vitals model

Four needs — **Calories, Hydration, Energy, Warmth** — drain continuously.
Warmth is driven by a feels-like temperature (ambient from season/time-of-day,
plus insulation and heat sources, minus wind chill and wetness). Any bottomed-out
need drains the single **Condition** pool (penalties stack); Condition only
regenerates when *all* needs are adequately met **and** the player is rested.
Afflictions (hypothermia, starvation, dehydration, exhaustion) are defined in
`game/data/afflictions.json` with data-driven triggers, effects, and cures.

## Milestone status

- [x] **M1 — Skeleton:** project structure, event bus, fixed-step tick,
      time/clock, player movement on a tilemap, debug HUD
- [x] **M2 — Vitals core:** four needs + Condition + warmth model +
      data-driven afflictions, unit-tested, HUD meters with mood text
- [ ] M3 — Inventory & items
- [ ] M4 — Gathering & tools
- [ ] M5 — Crafting
- [ ] M6 — World depth (seasons/weather/biomes; handcrafted core map)
- [ ] M7 — Building
- [ ] M8 — Skills & progression
- [ ] M9 — Quests
- [ ] M10 — NPCs & dialogue
- [ ] M11 — Story
- [ ] M12 — Save/load
- [ ] M13 — Polish
- [ ] M14 — Threats/combat
