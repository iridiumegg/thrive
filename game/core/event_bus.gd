## Global event bus (autoload "EventBus").
##
## Systems communicate through these signals instead of holding references to
## each other, keeping the simulation, world, and UI layers decoupled.
## Future milestones will add signals such as `item_crafted`, `quest_completed`,
## and `node_depleted` here as those systems come online.
extends Node

## Emitted by Sim once per simulated in-game minute (the fixed step).
signal sim_minute(minutes: int)

## Emitted by Sim when the in-game day index changes.
signal day_advanced(day: int)

## Emitted by Sim when the season changes.
signal season_changed(season_name: String)

## Emitted by the player's VitalsComponent after every vitals tick.
## `state` is a VitalsState (untyped here to avoid load-order coupling).
signal vitals_changed(state: RefCounted)

## Emitted when an affliction activates / is cured on the player.
signal affliction_started(id: String)
signal affliction_ended(id: String)

## Emitted once when the player's Condition reaches zero.
signal player_died

## --- Inventory / items (Milestone 3) ---

## Emitted after any change to the player's inventory. Payload is the Inventory.
signal inventory_changed(inventory: RefCounted)

## Emitted after any change to equipped gear. Payload is the Equipment.
signal equipment_changed(equipment: RefCounted)

## Emitted when the player picks up / drops an item (for feedback + quests).
signal item_picked_up(item_id: String, qty: int)
signal item_dropped(item_id: String, qty: int)

## A transient one-line message for the HUD (e.g. "Pack is full").
signal notice(text: String)

## --- Gathering / tools (Milestone 4) ---

## Current interaction hint for the HUD ("" when nothing is in range).
signal interaction_prompt(text: String)

## Emitted when the player successfully harvests a node (for skills/quests).
signal node_harvested(node_id: String, loot: Dictionary)

## --- Crafting (Milestone 5) ---

## Emitted when the craft queue changes (job started, completed, cancelled).
signal crafting_queue_changed(queue: Array)

## Emitted on each completed craft (recipe_id + the quality it was made at).
signal recipe_crafted(recipe_id: String, quality: String)

## Emitted when a recipe is newly learned (e.g. from a blueprint).
signal recipe_learned(recipe_id: String)

## Emitted when the set of in-range crafting stations changes. Payload is the
## list of available station ids (always includes "hand").
signal stations_changed(station_ids: Array)

## --- World depth (Milestone 6) ---

## Emitted when the weather state changes (id + display name).
signal weather_changed(state: String, display_name: String)

## Emitted when the player crosses into a different biome (biome id + name).
signal biome_entered(biome_id: String, display_name: String)

## --- Building (Milestone 7) ---

## Emitted when a structure is placed / removed (for quests + bookkeeping).
signal structure_built(buildable_id: String)
signal structure_removed(buildable_id: String)

## Emitted when build mode is toggled, so the HUD can show/hide the palette.
signal build_mode_changed(active: bool)

## Request to open a storage container's transfer screen.
signal storage_opened(container: RefCounted)

## Request to sleep through to morning (from a bed).
signal sleep_requested

## --- Skills & progression (Milestone 8) ---

## Emitted when a skill gains XP (level may or may not have changed).
signal skill_xp_gained(skill_id: String, amount: int)

## Emitted when a skill reaches a new level.
signal skill_leveled(skill_id: String, level: int)

## --- Quests (Milestone 9) ---

## Emitted when a quest becomes active / is completed.
signal quest_activated(quest_id: String)
signal quest_completed(quest_id: String)

## Emitted when any active quest's objective progress changes (for the journal).
signal quest_progress_changed

## Emitted when a story flag is set (narrative state hook for M11).
signal flag_set(flag: String)

## --- NPCs & dialogue (Milestone 10) ---

## Dialogue lifecycle for the UI. `node`/`choices` describe what to render.
signal dialogue_started(npc_id: String, npc_name: String)
signal dialogue_node(speaker: String, text: String, choices: Array)
signal dialogue_ended

## Emitted when an NPC relationship changes (id + new value + tier name).
signal relationship_changed(npc_id: String, value: int, tier: String)

## --- Story (Milestone 11) ---

## Emitted when a found document is read (for quests + the lore codex).
signal document_found(note_id: String)

## Show a document's text in the reader.
signal document_text(title: String, body: String)

## The finale is reachable; payload is the list of currently available endings.
signal ending_choices(endings: Array)

## An ending has been chosen — show it and wrap the run.
signal ending_reached(ending_id: String, title: String, body: String)

## --- Threats & combat (Milestone 14) ---

## Emitted when a creature is killed (for hunting loot + survival XP + quests).
signal creature_killed(creature_id: String)

## Emitted when the player takes a wound from wildlife.
signal player_wounded(creature_id: String, damage: float)
