extends Node3D

@onready var right_arm_pivot: Node3D = get_node_or_null("RightArmPivot")

var is_waving := false


func wave_goodbye() -> void:
	if not right_arm_pivot:
		return
	is_waving = true
	var tween := create_tween().set_loops(3)
	tween.tween_property(right_arm_pivot, "rotation:z", deg_to_rad(-45.0), 0.3)
	tween.tween_property(right_arm_pivot, "rotation:z", deg_to_rad(-15.0), 0.3)
	await tween.finished
	var reset_tween := create_tween()
	reset_tween.tween_property(right_arm_pivot, "rotation:z", 0.0, 0.4)
	await reset_tween.finished
	is_waving = false
