extends CanvasLayer

signal advance_requested

@onready var panel: PanelContainer = $PanelContainer
@onready var speaker_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderBox/SpeakerLabel
@onready var text_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TextLabel
@onready var prompt_label: Label = $PanelContainer/MarginContainer/VBoxContainer/PromptLabel

var is_active := false
var is_typing := false
var full_text := ""
var current_char_count := 0.0
var characters_per_second := 38.0
var prompt_tween: Tween

var speaker_colors := {
	"Marieke": Color(0.96, 0.82, 0.62, 1.0), # Warm gold/rose
	"Ich": Color(0.72, 0.88, 0.98, 1.0)       # Cool twilight blue
}

func _ready() -> void:
	hide_dialogue()


func _process(delta: float) -> void:
	if is_active and is_typing:
		current_char_count += delta * characters_per_second
		text_label.visible_characters = int(current_char_count)
		if text_label.visible_characters >= full_text.length():
			_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if is_typing:
			_finish_typing()
		else:
			advance_requested.emit()
		get_viewport().set_input_as_handled()


func show_line(speaker: String, text: String) -> void:
	is_active = true
	speaker_label.text = speaker.to_upper()
	
	if speaker_colors.has(speaker):
		speaker_label.add_theme_color_override("font_color", speaker_colors[speaker])
	else:
		speaker_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75, 1.0))

	full_text = text
	text_label.text = text
	text_label.visible_characters = 0
	current_char_count = 0.0
	is_typing = true

	prompt_label.text = "[E] / [ENTER] Weiter ▼"
	prompt_label.modulate.a = 0.3

	if not panel.visible:
		panel.visible = true
		panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.2)


func _finish_typing() -> void:
	is_typing = false
	text_label.visible_characters = -1
	_start_prompt_pulse()


func _start_prompt_pulse() -> void:
	if prompt_tween and prompt_tween.is_running():
		prompt_tween.kill()
	prompt_tween = create_tween().set_loops()
	prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.5)
	prompt_tween.tween_property(prompt_label, "modulate:a", 0.4, 0.5)


func hide_dialogue() -> void:
	is_active = false
	is_typing = false
	if prompt_tween and prompt_tween.is_running():
		prompt_tween.kill()
	panel.visible = false
