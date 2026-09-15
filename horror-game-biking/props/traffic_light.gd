extends StaticBody3D

enum State { RED, RED_YELLOW, GREEN, YELLOW }

@export var initial_state: State = State.RED

var current_state: State = State.RED
var is_switching: bool = false

# Node references
@onready var red_mesh: MeshInstance3D = $Housing/RedLens
@onready var yellow_mesh: MeshInstance3D = $Housing/YellowLens
@onready var green_mesh: MeshInstance3D = $Housing/GreenLens

@onready var red_light: OmniLight3D = $Housing/RedLight
@onready var yellow_light: OmniLight3D = $Housing/YellowLight
@onready var green_light: OmniLight3D = $Housing/GreenLight

@onready var button_indicator: MeshInstance3D = $ButtonBox/Indicator
@onready var interactable: Interactable = get_node_or_null("Interactable")


func _ready() -> void:
	current_state = initial_state
	_apply_state()
	
	if interactable:
		interactable.prompt_text = "Ampel anfordern"
		interactable.interacted.connect(request_crossing)


func request_crossing() -> void:
	if current_state != State.RED or is_switching:
		return
	
	is_switching = true
	if interactable:
		interactable.is_interactable = false
	
	if button_indicator:
		var mat = button_indicator.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission_enabled = true
	
	# Transition: Red -> Red-Yellow (after 1.5s) -> Green (after 1.2s)
	await get_tree().create_timer(1.5).timeout
	current_state = State.RED_YELLOW
	_apply_state()
	
	await get_tree().create_timer(1.2).timeout
	current_state = State.GREEN
	_apply_state()
	
	if button_indicator:
		var mat = button_indicator.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission_enabled = false
	
	# Stay Green for 8 seconds
	await get_tree().create_timer(8.0).timeout
	current_state = State.YELLOW
	_apply_state()
	
	# Yellow for 2 seconds
	await get_tree().create_timer(2.0).timeout
	current_state = State.RED
	_apply_state()
	is_switching = false
	if interactable:
		interactable.is_interactable = true


func _apply_state() -> void:
	var show_red = (current_state == State.RED or current_state == State.RED_YELLOW)
	var show_yellow = (current_state == State.RED_YELLOW or current_state == State.YELLOW)
	var show_green = (current_state == State.GREEN)
	
	if red_light:
		red_light.visible = show_red
	if yellow_light:
		yellow_light.visible = show_yellow
	if green_light:
		green_light.visible = show_green
	
	_set_lens_emission(red_mesh, show_red, Color(1.0, 0.1, 0.1))
	_set_lens_emission(yellow_mesh, show_yellow, Color(1.0, 0.8, 0.1))
	_set_lens_emission(green_mesh, show_green, Color(0.1, 1.0, 0.3))


func _set_lens_emission(mesh_inst: MeshInstance3D, enabled: bool, color: Color) -> void:
	if not mesh_inst:
		return
	var mat = mesh_inst.get_surface_override_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_inst.set_surface_override_material(0, mat)
	if mat is StandardMaterial3D:
		mat.emission_enabled = enabled
		mat.emission = color
		mat.emission_energy_multiplier = 3.0 if enabled else 0.0
