extends Control

@onready var character_list: VBoxContainer = $ScrollContainer/CharacterList

func _ready() -> void:
	_build_character_list()
	$BackButton.pressed.connect(_on_back_pressed)

func _build_character_list() -> void:
	for id: String in GameManager.characters:
		var data: Dictionary = GameManager.characters[id]
		var unlocked: bool = GameManager.is_character_unlocked(id)
		var row: HBoxContainer = _create_character_row(id, data, unlocked)
		character_list.add_child(row)

func _create_character_row(id: String, data: Dictionary, unlocked: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Sprite preview
	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(48, 48)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if data.has("sprite") and data["sprite"] != "":
		sprite.texture = load(data["sprite"])
	row.add_child(sprite)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = data.get("name", id)
	info.add_child(name_label)

	var stats_text: String = ""
	var stats: Dictionary = data.get("stats", {})
	for stat_name: String in stats:
		if stats_text != "":
			stats_text += " | "
		stats_text += "%s: %s" % [stat_name, str(stats[stat_name])]
	var items: Array = data.get("starting_items", [])
	if items.size() > 0:
		if stats_text != "":
			stats_text += " | "
		stats_text += "items: %d" % items.size()
	var resources: Dictionary = data.get("starting_resources", {})
	for res_name: String in resources:
		if stats_text != "":
			stats_text += " | "
		stats_text += "%s: %s" % [res_name, str(resources[res_name])]

	if stats_text != "":
		var stats_label := Label.new()
		stats_label.text = stats_text
		stats_label.add_theme_font_size_override("font_size", 12)
		info.add_child(stats_label)

	row.add_child(info)

	# Select button
	var button := Button.new()
	if unlocked:
		button.text = "Select"
		button.pressed.connect(_on_character_selected.bind(id))
	else:
		button.text = "Locked"
		button.disabled = true
	row.add_child(button)

	return row

func _on_character_selected(id: String) -> void:
	GameManager.set_character(id)
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
