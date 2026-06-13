## Narrative director: found documents and the branching finale. Shares the
## quest system's FlagStore so notes and endings read/write the same story state.
##
## Reading a document sets its flag, logs it in the codex, and emits a `discover`
## hook (so quests can require specific notes). When the decision quest activates,
## the available endings — filtered by what the player has done — are offered;
## choosing one sets an ending flag and ends the run.
class_name StoryComponent
extends Node

const DECISION_QUEST := "q_decision"

var codex: Array[String] = []   # ids of documents read, in order
var ended := false

var _quests: QuestComponent

func setup(quests: QuestComponent) -> void:
	_quests = quests

func _ready() -> void:
	EventBus.quest_activated.connect(_on_quest_activated)

## Read a found document (idempotent).
func read_document(note_id: String) -> void:
	var note: Dictionary = LoreDb.get_note(note_id)
	if note.is_empty():
		return
	EventBus.document_text.emit(String(note.get("title", "")), String(note.get("body", "")))
	if note_id in codex:
		return
	codex.append(note_id)
	_quests.flags.set_flag(String(note.get("flag", "")))
	EventBus.flag_set.emit(String(note.get("flag", "")))
	EventBus.document_found.emit(note_id)
	EventBus.notice.emit("Found: %s" % note.get("title", "a document"))

func has_read(note_id: String) -> bool:
	return note_id in codex

func save() -> Dictionary:
	return {"codex": Array(codex), "ended": ended}

func load_save(data: Dictionary) -> void:
	codex.clear()
	for id: String in data.get("codex", []):
		codex.append(String(id))
	ended = bool(data.get("ended", false))

## --- Endings ---

func _on_quest_activated(quest_id: String) -> void:
	if quest_id == DECISION_QUEST:
		EventBus.ending_choices.emit(available_endings())

func available_endings() -> Array:
	return Endings.available(LoreDb.endings, _quests.flags.all_flags())

func choose_ending(ending_id: String) -> void:
	if ended:
		return
	var ending: Dictionary = LoreDb.get_ending(ending_id)
	if ending.is_empty() or not Endings.is_available(ending, _quests.flags.all_flags()):
		return
	ended = true
	_quests.flags.set_flag("ending_" + ending_id)
	EventBus.flag_set.emit("ending_" + ending_id)
	EventBus.ending_reached.emit(ending_id, String(ending["title"]), String(ending["body"]))
