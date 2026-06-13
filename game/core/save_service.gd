## Save service (autoload "SaveService").
##
## Handles file IO and holds a pending snapshot across a scene reload. The world
## builds/consumes the actual state dict (gather_save / apply_save); this service
## versions it, writes human-readable JSON to user://, and supports migration.
extends Node

const SAVE_PATH := "user://thrive_save.json"
const SAVE_VERSION := 1

## A snapshot waiting to be applied after the scene reloads (set by request_load).
var pending: Dictionary = {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func has_pending() -> bool:
	return not pending.is_empty()

func take_pending() -> Dictionary:
	var data := pending
	pending = {}
	return data

## Write a state dict (from world.gather_save) to disk, stamped with a version.
func write(state: Dictionary) -> bool:
	state["version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing")
		return false
	file.store_string(JSON.stringify(state, "  "))
	file.close()
	return true

## Read + migrate the save from disk. Returns {} if absent/corrupt.
func read() -> Dictionary:
	if not has_save():
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Save file is corrupt")
		return {}
	return _migrate(parsed)

## Stage the on-disk save to be applied after a scene reload.
func request_load() -> bool:
	var data := read()
	if data.is_empty():
		return false
	pending = data
	return true

## Forward-compatible migration: bring older saves up to the current schema.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 1))
	# (No migrations yet; future schema bumps add steps here.)
	if version > SAVE_VERSION:
		push_warning("Save is from a newer version (%d) than supported (%d)" % [version, SAVE_VERSION])
	return data
