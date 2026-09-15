extends Node3D

@export var max_interaction_distance: float = 3.5
@export var max_shimmer_distance: float = 8.0 # Ca. doppelte Reichweite
@export var view_angle_threshold_deg: float = 55.0 # Großzügiger Blickwinkel

var current_target: Interactable = null
var nearby_shimmer_targets: Array[Interactable] = []

@onready var camera: Camera3D = get_parent().get_node_or_null("Camera3D") as Camera3D
@onready var prompt_label: Label3D = get_node_or_null("PromptLabel3D") as Label3D


func _process(_delta: float) -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return

	_update_interactions()


func _update_interactions() -> void:
	var interactables = get_tree().get_nodes_in_group("interactables")
	var cam_pos = camera.global_position
	var cam_forward = -camera.global_transform.basis.z.normalized()

	var best_target: Interactable = null
	var best_score: float = -999.0
	var new_shimmer_list: Array[Interactable] = []

	for node in interactables:
		if not (node is Interactable):
			continue
		var obj = node as Interactable
		if not obj.is_interactable or not obj.is_inside_tree():
			continue

		var obj_pos = obj.global_position
		var to_obj = obj_pos - cam_pos
		var dist = to_obj.length()
		var dir_to_obj = to_obj.normalized()

		var dot = cam_forward.dot(dir_to_obj)
		var angle_deg = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))

		# Schimmer-Erkennung für kleine Items auf mittlere Entfernung
		if dist <= max_shimmer_distance and angle_deg <= 75.0:
			if obj.is_small_item:
				new_shimmer_list.append(obj)
				obj.set_shimmer(true)

		# Interaktions-Erkennung (großzügig)
		if dist <= max_interaction_distance and angle_deg <= view_angle_threshold_deg:
			# Score: Kombination aus Blickzentrum (dot) und Nähe
			var score = dot * 2.0 - (dist / max_interaction_distance)
			if score > best_score:
				best_score = score
				best_target = obj

	# Alte Schimmer-Objekte zurücksetzen
	for prev in nearby_shimmer_targets:
		if is_instance_valid(prev) and not new_shimmer_list.has(prev):
			prev.set_shimmer(false)
	nearby_shimmer_targets = new_shimmer_list

	# Target wechseln
	if best_target != current_target:
		if is_instance_valid(current_target):
			current_target.set_focus(false)
		current_target = best_target
		if is_instance_valid(current_target):
			current_target.set_focus(true)
			if prompt_label:
				prompt_label.text = "[E] " + current_target.prompt_text
				prompt_label.visible = true
				prompt_label.global_position = current_target.global_position + Vector3(0, 0.35, 0)
		else:
			if prompt_label:
				prompt_label.visible = false
	elif is_instance_valid(current_target) and prompt_label:
		prompt_label.global_position = current_target.global_position + Vector3(0, 0.35, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		if is_instance_valid(current_target) and current_target.is_interactable:
			current_target.interact()
			# Nach Interaktion kurz prüfen
			if not current_target.is_interactable:
				if prompt_label:
					prompt_label.visible = false
