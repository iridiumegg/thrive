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
