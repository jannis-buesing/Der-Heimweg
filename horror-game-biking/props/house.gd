@tool
extends StaticBody3D

enum WallColor { CREAM, BRICK_RED, DARK_WOOD, BLUE_GRAY, OLIVE }
enum RoofType { GABLE, HIP, FLAT }
enum RoofColor { SLATE_GRAY, TERRACOTTA, CHARCOAL }

@export_group("House Shape")
@export var stories: int = 1:
	set(value):
		stories = clamp(value, 1, 2)
		_update_house()

@export var roof_type: RoofType = RoofType.GABLE:
	set(value):
		roof_type = value
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

@export_group("Addons")
@export var has_garage: bool = false:
	set(value):
		has_garage = value
		_update_house()

@export var has_chimney: bool = true:
	set(value):
		has_chimney = value
		_update_house()

@export var has_porch: bool = true:
	set(value):
		has_porch = value
		_update_house()

@export var lit_windows: bool = true:
	set(value):
		lit_windows = value
		_update_windows()

# Node References
@onready var body_mesh: MeshInstance3D = get_node_or_null("Body")
@onready var upper_body_mesh: MeshInstance3D = get_node_or_null("UpperBody")
@onready var roof_gable: MeshInstance3D = get_node_or_null("RoofGable")
@onready var roof_hip: MeshInstance3D = get_node_or_null("RoofHip")
@onready var roof_flat: MeshInstance3D = get_node_or_null("RoofFlat")
@onready var chimney: MeshInstance3D = get_node_or_null("Chimney")
@onready var garage: Node3D = get_node_or_null("Garage")
@onready var porch: Node3D = get_node_or_null("Porch")
@onready var upper_windows: Node3D = get_node_or_null("UpperWindows")
@onready var main_collision: CollisionShape3D = get_node_or_null("CollisionMain")
@onready var garage_collision: CollisionShape3D = get_node_or_null("CollisionGarage")


func _ready() -> void:
	_update_house()
	_update_materials()
	_update_windows()


func _update_house() -> void:
	var wall_height = 3.2 if stories == 1 else 6.0
	
	if body_mesh:
		body_mesh.visible = true
		body_mesh.position.y = 1.6
		if body_mesh.mesh is BoxMesh:
			var box = body_mesh.mesh as BoxMesh
			box.size = Vector3(7.5, 3.2, 9.0)
	
	if upper_body_mesh:
		upper_body_mesh.visible = (stories == 2)
		upper_body_mesh.position.y = 4.5
	
	if upper_windows:
		upper_windows.visible = (stories == 2)
	
	var roof_y = 3.2 if stories == 1 else 6.0
	
	if roof_gable:
		roof_gable.visible = (roof_type == RoofType.GABLE)
		roof_gable.position.y = roof_y + 1.25
	
	if roof_hip:
		roof_hip.visible = (roof_type == RoofType.HIP)
		roof_hip.position.y = roof_y + 1.1
	
	if roof_flat:
		roof_flat.visible = (roof_type == RoofType.FLAT)
		roof_flat.position.y = roof_y + 0.15
	
	if chimney:
		chimney.visible = has_chimney and (roof_type != RoofType.FLAT)
		chimney.position.y = roof_y + 1.8
	
	if garage:
		garage.visible = has_garage
	
	if garage_collision:
		garage_collision.disabled = !has_garage
	
	if porch:
		porch.visible = has_porch
	
	if main_collision and main_collision.shape is BoxShape3D:
		var shape = main_collision.shape as BoxShape3D
		shape.size = Vector3(7.8, wall_height + 1.5, 9.2)
		main_collision.position.y = (wall_height + 1.5) * 0.5


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
	
	if body_mesh:
		body_mesh.material_override = wall_mat
	if upper_body_mesh:
		upper_body_mesh.material_override = wall_mat
	
	var garage_body = get_node_or_null("Garage/GarageBody") as MeshInstance3D
	if garage_body:
		garage_body.material_override = wall_mat
	
	var roof_mat = StandardMaterial3D.new()
	roof_mat.roughness = 0.75
	match roof_color:
		RoofColor.SLATE_GRAY:
			roof_mat.albedo_color = Color(0.20, 0.22, 0.25)
		RoofColor.TERRACOTTA:
			roof_mat.albedo_color = Color(0.60, 0.30, 0.20)
		RoofColor.CHARCOAL:
			roof_mat.albedo_color = Color(0.12, 0.12, 0.13)
	
	if roof_gable:
		roof_gable.material_override = roof_mat
	if roof_hip:
		roof_hip.material_override = roof_mat
	if roof_flat:
		roof_flat.material_override = roof_mat


func _update_windows() -> void:
	var lit_mat = StandardMaterial3D.new()
	lit_mat.albedo_color = Color(1.0, 0.88, 0.55)
	lit_mat.emission_enabled = lit_windows
	lit_mat.emission = Color(0.95, 0.75, 0.35)
	lit_mat.emission_energy_multiplier = 1.2
	
	var dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.08, 0.09, 0.12)
	dark_mat.roughness = 0.2
	
	var win1 = get_node_or_null("GroundWindows/WindowLit") as MeshInstance3D
	if win1:
		win1.material_override = lit_mat if lit_windows else dark_mat
	
	var win_side = get_node_or_null("GroundWindows/WindowSideLit") as MeshInstance3D
	if win_side:
		win_side.material_override = lit_mat if lit_windows else dark_mat
