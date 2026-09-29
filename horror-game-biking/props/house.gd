@tool
extends StaticBody3D

enum WallColor { CREAM, BRICK_RED, DARK_WOOD, BLUE_GRAY, OLIVE, MOSS_GREEN, OCHRE }
enum RoofType { GABLE, HIP, FLAT, MANSARD }
enum RoofColor { SLATE_GRAY, TERRACOTTA, CHARCOAL, DARK_BROWN }
enum GaragePosition { NONE, LEFT, RIGHT }
enum WindowState { DARK, LIT, CURTAIN, INHABITED }
enum SilhouetteType { NONE, STANDING, SITTING, LOOKING_OUT }

@export_group("House Shape & Structure")
@export var stories: int = 1:
	set(value):
		stories = clamp(value, 1, 3)
		_update_house()

@export var roof_type: RoofType = RoofType.GABLE:
	set(value):
		roof_type = value
		_update_house()

@export var has_foundation: bool = true:
	set(value):
		has_foundation = value
		_update_house()

@export var has_roof_overhang: bool = true:
	set(value):
		has_roof_overhang = value
		_update_house()

@export_group("Addons & Features")
@export var garage_position: GaragePosition = GaragePosition.NONE:
	set(value):
		garage_position = value
		_update_house()

@export var has_extension: bool = false:
	set(value):
		has_extension = value
		_update_house()

@export var has_chimney: bool = true:
	set(value):
		has_chimney = value
		_update_house()

@export var has_porch: bool = true:
	set(value):
		has_porch = value
		_update_house()

@export_group("Materials & Colors")
@export var wall_color: WallColor = WallColor.CREAM:
	set(value):
		wall_color = value
		_update_materials()

@export var roof_color: RoofColor = RoofColor.SLATE_GRAY:
	set(value):
		roof_color = value
		_update_materials()

@export var trim_color: Color = Color(0.18, 0.15, 0.12):
	set(value):
		trim_color = value
		_update_materials()

@export_group("Lighting & Inhabited Room")
@export var ground_window_state: WindowState = WindowState.LIT:
	set(value):
		ground_window_state = value
		_update_windows()

@export var upper_window_state: WindowState = WindowState.DARK:
	set(value):
		upper_window_state = value
		_update_windows()

@export var extension_window_state: WindowState = WindowState.DARK:
	set(value):
		extension_window_state = value
		_update_windows()

@export var person_silhouette: SilhouetteType = SilhouetteType.NONE:
	set(value):
		person_silhouette = value
		_update_windows()

@export_group("Editor Tools")
@export var randomize_now: bool = false:
	set(value):
		if value:
			randomize_house()
		randomize_now = false

# Internal Node References
@onready var body_mesh: MeshInstance3D = get_node_or_null("Body")
@onready var upper_body_mesh: MeshInstance3D = get_node_or_null("UpperBody")
@onready var third_body_mesh: MeshInstance3D = get_node_or_null("ThirdBody")
@onready var foundation_mesh: MeshInstance3D = get_node_or_null("Foundation")

@onready var roof_gable: MeshInstance3D = get_node_or_null("RoofGable")
@onready var roof_hip: MeshInstance3D = get_node_or_null("RoofHip")
@onready var roof_flat: MeshInstance3D = get_node_or_null("RoofFlat")
@onready var roof_mansard: MeshInstance3D = get_node_or_null("RoofMansard")
@onready var roof_overhang_mesh: MeshInstance3D = get_node_or_null("RoofOverhang")

@onready var chimney: MeshInstance3D = get_node_or_null("Chimney")
@onready var garage: Node3D = get_node_or_null("Garage")
@onready var extension: Node3D = get_node_or_null("Extension")
@onready var porch: Node3D = get_node_or_null("Porch")

@onready var ground_windows_node: Node3D = get_node_or_null("GroundWindows")
@onready var upper_windows_node: Node3D = get_node_or_null("UpperWindows")
@onready var extension_windows_node: Node3D = get_node_or_null("ExtensionWindows")

@onready var room_interior_node: Node3D = get_node_or_null("RoomInterior")

@onready var main_collision: CollisionShape3D = get_node_or_null("CollisionMain")
@onready var garage_collision: CollisionShape3D = get_node_or_null("CollisionGarage")


func _ready() -> void:
	_update_house()
	_update_materials()
	_update_windows()


func randomize_house(custom_seed: int = -1) -> void:
	if custom_seed >= 0:
		seed(custom_seed)
	
	stories = randi_range(1, 2)
	roof_type = randi() % RoofType.size() as RoofType
	wall_color = randi() % WallColor.size() as WallColor
	roof_color = randi() % RoofColor.size() as RoofColor
	has_foundation = true
	has_roof_overhang = randf() > 0.2
	
	var gar_roll = randf()
	if gar_roll < 0.4:
		garage_position = GaragePosition.LEFT
	elif gar_roll < 0.7:
		garage_position = GaragePosition.RIGHT
	else:
		garage_position = GaragePosition.NONE
	
	has_extension = (randf() > 0.5)
	has_chimney = (randf() > 0.3)
	has_porch = (randf() > 0.2)
	
	# Random window states
	var states = [WindowState.DARK, WindowState.LIT, WindowState.CURTAIN, WindowState.INHABITED]
	ground_window_state = states[randi() % states.size()]
	upper_window_state = states[randi() % states.size()]
	extension_window_state = states[randi() % states.size()]
	
	if ground_window_state == WindowState.INHABITED or upper_window_state == WindowState.INHABITED:
		var sil_options = [SilhouetteType.NONE, SilhouetteType.STANDING, SilhouetteType.SITTING, SilhouetteType.LOOKING_OUT]
		person_silhouette = sil_options[randi() % sil_options.size()]
	else:
		person_silhouette = SilhouetteType.NONE
	
	_update_house()
	_update_materials()
	_update_windows()


func _update_house() -> void:
	var story_height := 3.0
	var total_wall_height := story_height * stories
	
	if foundation_mesh:
		foundation_mesh.visible = has_foundation
		foundation_mesh.position.y = 0.2
	
	if body_mesh:
		body_mesh.visible = true
		body_mesh.position.y = 0.4 + story_height * 0.5
	
	if upper_body_mesh:
		upper_body_mesh.visible = (stories >= 2)
		upper_body_mesh.position.y = 0.4 + story_height * 1.5
	
	if third_body_mesh:
		third_body_mesh.visible = (stories >= 3)
		third_body_mesh.position.y = 0.4 + story_height * 2.5
	
	if upper_windows_node:
		upper_windows_node.visible = (stories >= 2)
	
	var roof_y = 0.4 + total_wall_height
	
	if roof_gable:
		roof_gable.visible = (roof_type == RoofType.GABLE)
		roof_gable.position.y = roof_y + 1.25
	
	if roof_hip:
		roof_hip.visible = (roof_type == RoofType.HIP)
		roof_hip.position.y = roof_y + 1.1
	
	if roof_flat:
		roof_flat.visible = (roof_type == RoofType.FLAT)
		roof_flat.position.y = roof_y + 0.15
	
	if roof_mansard:
		roof_mansard.visible = (roof_type == RoofType.MANSARD)
		roof_mansard.position.y = roof_y + 0.9
	
	if roof_overhang_mesh:
		roof_overhang_mesh.visible = has_roof_overhang and (roof_type != RoofType.FLAT)
		roof_overhang_mesh.position.y = roof_y + 0.05
	
	if chimney:
		chimney.visible = has_chimney and (roof_type != RoofType.FLAT)
		chimney.position.y = roof_y + 1.8
	
	if garage:
		garage.visible = (garage_position != GaragePosition.NONE)
		if garage_position == GaragePosition.LEFT:
			garage.position.x = -5.8
		elif garage_position == GaragePosition.RIGHT:
			garage.position.x = 5.8
	
	if garage_collision:
		garage_collision.disabled = (garage_position == GaragePosition.NONE)
		if garage_position == GaragePosition.LEFT:
			garage_collision.position.x = -5.8
		elif garage_position == GaragePosition.RIGHT:
			garage_collision.position.x = 5.8
	
	if extension:
		extension.visible = has_extension
		# Place extension opposite to garage if garage exists
		if garage_position == GaragePosition.LEFT:
			extension.position.x = 5.6
		else:
			extension.position.x = -5.6
	
	if porch:
		porch.visible = has_porch
	
	if main_collision and main_collision.shape is BoxShape3D:
		var shape = main_collision.shape as BoxShape3D
		shape.size = Vector3(7.8, total_wall_height + 1.5, 9.2)
		main_collision.position.y = (total_wall_height + 1.5) * 0.5


func _update_materials() -> void:
	var wall_mat = StandardMaterial3D.new()
	wall_mat.roughness = 0.85
	match wall_color:
		WallColor.CREAM:
			wall_mat.albedo_color = Color(0.82, 0.79, 0.72)
		WallColor.BRICK_RED:
			wall_mat.albedo_color = Color(0.55, 0.24, 0.20)
		WallColor.DARK_WOOD:
			wall_mat.albedo_color = Color(0.25, 0.18, 0.13)
		WallColor.BLUE_GRAY:
			wall_mat.albedo_color = Color(0.35, 0.40, 0.44)
		WallColor.OLIVE:
			wall_mat.albedo_color = Color(0.32, 0.36, 0.28)
		WallColor.MOSS_GREEN:
			wall_mat.albedo_color = Color(0.22, 0.30, 0.22)
		WallColor.OCHRE:
			wall_mat.albedo_color = Color(0.72, 0.55, 0.30)
	
	if body_mesh:
		body_mesh.material_override = wall_mat
	if upper_body_mesh:
		upper_body_mesh.material_override = wall_mat
	if third_body_mesh:
		third_body_mesh.material_override = wall_mat
	
	var garage_body = get_node_or_null("Garage/GarageBody") as MeshInstance3D
	if garage_body:
		garage_body.material_override = wall_mat
	
	var ext_body = get_node_or_null("Extension/ExtensionBody") as MeshInstance3D
	if ext_body:
		ext_body.material_override = wall_mat
	
	var roof_mat = StandardMaterial3D.new()
	roof_mat.roughness = 0.75
	match roof_color:
		RoofColor.SLATE_GRAY:
			roof_mat.albedo_color = Color(0.20, 0.22, 0.25)
		RoofColor.TERRACOTTA:
			roof_mat.albedo_color = Color(0.60, 0.30, 0.20)
		RoofColor.CHARCOAL:
			roof_mat.albedo_color = Color(0.12, 0.12, 0.13)
		RoofColor.DARK_BROWN:
			roof_mat.albedo_color = Color(0.22, 0.15, 0.10)
	
	if roof_gable:
		roof_gable.material_override = roof_mat
	if roof_hip:
		roof_hip.material_override = roof_mat
	if roof_flat:
		roof_flat.material_override = roof_mat
	if roof_mansard:
		roof_mansard.material_override = roof_mat
	if roof_overhang_mesh:
		roof_overhang_mesh.material_override = roof_mat
	
	var found_mat = StandardMaterial3D.new()
	found_mat.albedo_color = Color(0.18, 0.18, 0.19)
	found_mat.roughness = 0.95
	if foundation_mesh:
		foundation_mesh.material_override = found_mat


func _update_windows() -> void:
	_apply_window_state(ground_windows_node, ground_window_state)
	_apply_window_state(upper_windows_node, upper_window_state)
	_apply_window_state(extension_windows_node, extension_window_state)
	
	_update_inhabited_room()


func _apply_window_state(parent_node: Node3D, state: WindowState) -> void:
	if parent_node == null:
		return
	
	var lit_mat = StandardMaterial3D.new()
	lit_mat.roughness = 0.3
	
	match state:
		WindowState.DARK:
			lit_mat.albedo_color = Color(0.06, 0.07, 0.09)
			lit_mat.emission_enabled = false
		WindowState.LIT:
			lit_mat.albedo_color = Color(1.0, 0.88, 0.55)
			lit_mat.emission_enabled = true
			lit_mat.emission = Color(0.95, 0.75, 0.35)
			lit_mat.emission_energy_multiplier = 1.4
		WindowState.CURTAIN:
			lit_mat.albedo_color = Color(0.85, 0.70, 0.50)
			lit_mat.emission_enabled = true
			lit_mat.emission = Color(0.80, 0.60, 0.30)
			lit_mat.emission_energy_multiplier = 0.8
		WindowState.INHABITED:
			lit_mat.albedo_color = Color(0.9, 0.9, 0.9, 0.3)
			lit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lit_mat.roughness = 0.1
			lit_mat.emission_enabled = true
			lit_mat.emission = Color(0.4, 0.35, 0.2, 0.5)
			lit_mat.emission_energy_multiplier = 0.3
	
	for child in parent_node.get_children():
		if child is MeshInstance3D:
			child.material_override = lit_mat


func _update_inhabited_room() -> void:
	if room_interior_node == null:
		return
	
	var is_inhabited = (
		ground_window_state == WindowState.INHABITED or
		upper_window_state == WindowState.INHABITED or
		extension_window_state == WindowState.INHABITED
	)
	
	room_interior_node.visible = is_inhabited
	
	if not is_inhabited:
		return
	
	if ground_window_state == WindowState.INHABITED:
		room_interior_node.position = Vector3(1.8, 1.6, -3.8)
	elif upper_window_state == WindowState.INHABITED:
		room_interior_node.position = Vector3(1.8, 4.5, -3.8)
	elif extension_window_state == WindowState.INHABITED:
		room_interior_node.position = Vector3(-5.6, 1.6, -3.8)
	
	var sil_node = room_interior_node.get_node_or_null("PersonSilhouette")
	if sil_node != null:
		sil_node.visible = (person_silhouette != SilhouetteType.NONE)
		
		match person_silhouette:
			SilhouetteType.STANDING:
				sil_node.position = Vector3(0.0, 0.0, -0.4)
				sil_node.scale = Vector3(0.35, 1.4, 0.2)
			SilhouetteType.SITTING:
				sil_node.position = Vector3(0.2, -0.3, -0.5)
				sil_node.scale = Vector3(0.4, 0.9, 0.3)
			SilhouetteType.LOOKING_OUT:
				sil_node.position = Vector3(0.0, 0.1, -0.1)
				sil_node.scale = Vector3(0.38, 1.45, 0.2)
