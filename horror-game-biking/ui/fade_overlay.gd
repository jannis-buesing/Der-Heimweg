extends CanvasLayer

signal fade_completed

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	color_rect.color.a = 0.0


func fade_out(duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished
	fade_completed.emit()


func fade_in(duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	fade_completed.emit()


func set_black() -> void:
	color_rect.color.a = 1.0


func set_transparent() -> void:
	color_rect.color.a = 0.0
