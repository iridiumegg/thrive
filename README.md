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
| WASD / arrows | Move (walk over items to pick them up) |
| E / Space | Interact: harvest a node, drink at a spring, work a trap, talk |
| F | Attack the nearest creature in range |
| Q | Deploy a snare trap (consumes a trap kit + bait) |
| Tab / I | Open / close the inventory & equipment screen |
| C | Open / close the crafting screen |
| B | Build mode (place stations, heat, shelter, storage, beds) |
| J | Open / close the quest journal |
| Left-click slot | Use food / equip gear / read a blueprint |
| Right-click slot | Drop one |
| F9 / F10 | Save / load game |
| F1 | Eat (debug quick-restore) |
| F2 | Drink (debug quick-restore) |
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
  /data        # balance, afflictions, items, world_spawns, resource_nodes,
               #   loot_tables, traps, recipes, stations (tunables + content)
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
- [x] **M3 — Inventory & items:** weight-based grid inventory, data-driven
      item defs, world pickups (seeded placement), equipment slots feeding
      the warmth model, encumbrance, eat/drink/equip/drop, inventory UI
- [x] **M4 — Gathering & tools:** resource nodes with yield tables, depletion
      & seeded respawn; tool tiers + durability gating node access (soft tech
      tree); weighted seed-aware loot tables; passive baited trapping
      subsystem; springs for water. (Open knob resolved: trapping included;
      fishing/hunting deferred.)
- [x] **M5 — Crafting:** data-driven recipe engine with a timed job queue
      (passive processing over sim time); hand-crafting + stations (workbench,
      campfire, forge, tailoring bench) via proximity; multi-step processing
      chains (ore → ingot → iron tool); cooking tree; blueprint recipe
      discovery; repair & salvage; full crafting UI. (Quality tiers:
      schema-ready, shipped off — switches on in M8.)
- [x] **M6 — World depth:** seeded weather state machine (clear→cloudy→
      rain/snow→storm) feeding wind chill + wetness into the warmth model,
      with rain/snow chosen by temperature and season-weighted odds; biome map
      (handcrafted outpost core + seeded surrounding regions) shifting ambient
      temperature and gating resource spawns; day/night + weather lighting.
- [x] **M7 — Building:** grid-snapped placement with a ghost preview, material
      costs, and pick-up/refund; one BuildingEntity covers stations, heat
      sources, shelter, storage chests, and beds; shelter + heat cancel wind
      chill/wetness; beds sleep through to morning; storage transfer UI. The
      outpost's stations are now these placeables.
- [x] **M8 — Skills & progression:** seven skill lines that level through use
      (gathering, crafting, smithing, cooking, tailoring, building, survival);
      leveling unlocks skill-gated recipes, grants gathering bonus loot rolls,
      and switches on crafted quality tiers (Crude→Masterwork) that scale tool
      durability and bonus output. Soft tech tree = tool tiers + stations +
      skills + blueprints.
- [x] **M9 — Quests:** data-driven quest engine (locked→active→completed) with
      objective tracking driven by gameplay events (gather/craft/build/
      survive-days/reach-skill/discover); prerequisite-chained activation that
      advances the story automatically; story-flag store (foundation for M11);
      reward grants (items/xp/recipes/flags); a five-quest tutorial arc and a
      journal with an always-on tracker.
- [x] **M10 — NPCs & dialogue:** two original characters (Wend, Old Pell) with
      time-of-day schedules who walk to their anchors; node-based branching
      dialogue reading/writing story flags; an original relationship/trust
      meter (Stranger→Trusted) that gates lines, trades, and teaching;
      dialogue-driven barter; lore that sets story flags for M11.
- [x] **M11 — Story:** original premise delivered through environment and
      found documents (five readable notes that set story flags and fill a lore
      codex); the main arc runs to a finale (What They Left Behind → The
      Outpost's Fate); three branching endings (Leave / Stay / Change) gated by
      what the player did and learned, with Leave always reachable.
- [x] **M12 — Save/load:** versioned, human-readable JSON saves of the full
      simulation — vitals/afflictions, inventory/equipment/durability, skills,
      crafting queue + known recipes, quests + story flags, relationships,
      lore codex, clock/weather, placed structures (+ chest contents), node
      depletion/respawn, traps, and ground items. Autosave on day change +
      manual save/load; migration-ready schema.
- [x] **M13 — Polish:** fully procedural audio (cues for pickup/craft/level-up/
      quest/build/warning plus a wind bed that swells with cold and storms, all
      synthesised at runtime — no audio files); a vital-warning cue that fires
      the moment a need crosses critical; accessibility config (master volume,
      UI text scale wired into HUD readouts, colorblind-safe meter cues that
      already pair color with icon + label + position).
- [x] **M14 — Threats/combat:** survival-flavored wildlife with a pure
      state-machine AI (idle/investigate/flee/attack); timid elk flee, nocturnal
      frost wolves hunt near the cold biomes — but a fire deters them and
      shelter makes you untargetable, so avoidance is first-class. Wounds feed
      an externally-triggered infection affliction cured only by a crafted
      bandage; swinging costs energy and scales with the equipped tool. Killing
      wildlife drops meat/hide (the hunting loop) and grants survival XP.
- [ ] M10 — NPCs & dialogue
- [ ] M11 — Story
- [ ] M12 — Save/load
- [ ] M13 — Polish
- [ ] M14 — Threats/combat
