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
