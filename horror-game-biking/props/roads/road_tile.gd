@tool
extends Node3D

enum RoadType { STRAIGHT, CURVE, T_JUNCTION, CROSSROAD, DEAD_END }

@export_group("Road Configuration")
@export var road_type: RoadType = RoadType.STRAIGHT:
	set(value):
		road_type = value
		_update_tile()

@export var tile_size: float = 12.0:
	set(value):
		tile_size = max(4.0, value)
		_update_tile()

@export var road_width: float = 6.0:
	set(value):
		road_width = clamp(value, 3.0, tile_size - 1.0)
		_update_tile()

@export var has_center_line: bool = true:
	set(value):
		has_center_line = value
		_update_tile()

@export var has_sidewalk_left: bool = true:
	set(value):
		has_sidewalk_left = value
		_update_tile()

@export var has_sidewalk_right: bool = true:
	set(value):
		has_sidewalk_right = value
		_update_tile()

@export var has_streetlight: bool = false:
	set(value):
		has_streetlight = value
		_update_tile()

# Child nodes
@onready var asphalt_mesh: MeshInstance3D = get_node_or_null("Asphalt")
@onready var markings_node: Node3D = get_node_or_null("Markings")
@onready var sidewalk_left: MeshInstance3D = get_node_or_null("SidewalkLeft")
@onready var sidewalk_right: MeshInstance3D = get_node_or_null("SidewalkRight")
@onready var curb_left: MeshInstance3D = get_node_or_null("CurbLeft")
@onready var curb_right: MeshInstance3D = get_node_or_null("CurbRight")
@onready var streetlight_node: Node3D = get_node_or_null("StreetLight")


func _ready() -> void:
	_update_tile()


func _update_tile() -> void:
	var asphalt_mat = StandardMaterial3D.new()
	asphalt_mat.albedo_color = Color(0.12, 0.12, 0.13)
	asphalt_mat.roughness = 0.85
	
	var curb_mat = StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.42, 0.42, 0.45)
	curb_mat.roughness = 0.7
	
	var sidewalk_mat = StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.55, 0.54, 0.52)
	sidewalk_mat.roughness = 0.8
	
	var paint_mat = StandardMaterial3D.new()
	paint_mat.albedo_color = Color(0.85, 0.85, 0.82)
	paint_mat.roughness = 0.6
	
	# Update Asphalt
	if asphalt_mesh:
		asphalt_mesh.material_override = asphalt_mat
		if asphalt_mesh.mesh is BoxMesh:
			var box = asphalt_mesh.mesh as BoxMesh
			match road_type:
				RoadType.STRAIGHT:
					box.size = Vector3(road_width, 0.05, tile_size)
				RoadType.CURVE, RoadType.T_JUNCTION, RoadType.CROSSROAD:
					box.size = Vector3(tile_size, 0.05, tile_size)
				RoadType.DEAD_END:
					box.size = Vector3(road_width + 2.0, 0.05, tile_size)
	
	# Update Sidewalks & Curbs
	var sidewalk_w = (tile_size - road_width) * 0.5
	var curb_w = 0.2
	var curb_h = 0.12
	var sidewalk_h = 0.10
	
	if sidewalk_left:
		sidewalk_left.visible = has_sidewalk_left
		sidewalk_left.material_override = sidewalk_mat
		sidewalk_left.position = Vector3(-(road_width * 0.5 + sidewalk_w * 0.5), sidewalk_h * 0.5, 0.0)
		if sidewalk_left.mesh is BoxMesh:
			(sidewalk_left.mesh as BoxMesh).size = Vector3(sidewalk_w, sidewalk_h, tile_size)
	
	if curb_left:
		curb_left.visible = has_sidewalk_left
		curb_left.material_override = curb_mat
		curb_left.position = Vector3(-(road_width * 0.5 + curb_w * 0.5), curb_h * 0.5, 0.0)
		if curb_left.mesh is BoxMesh:
			(curb_left.mesh as BoxMesh).size = Vector3(curb_w, curb_h, tile_size)
	
	if sidewalk_right:
		sidewalk_right.visible = has_sidewalk_right
		sidewalk_right.material_override = sidewalk_mat
		sidewalk_right.position = Vector3(road_width * 0.5 + sidewalk_w * 0.5, sidewalk_h * 0.5, 0.0)
		if sidewalk_right.mesh is BoxMesh:
			(sidewalk_right.mesh as BoxMesh).size = Vector3(sidewalk_w, sidewalk_h, tile_size)
	
	if curb_right:
		curb_right.visible = has_sidewalk_right
		curb_right.material_override = curb_mat
		curb_right.position = Vector3(road_width * 0.5 + curb_w * 0.5, curb_h * 0.5, 0.0)
		if curb_right.mesh is BoxMesh:
			(curb_right.mesh as BoxMesh).size = Vector3(curb_w, curb_h, tile_size)
	
	# Update Markings
	if markings_node:
		markings_node.visible = has_center_line
	
	# Update Streetlight
	if streetlight_node:
		streetlight_node.visible = has_streetlight
		if has_streetlight:
			streetlight_node.position = Vector3(-(road_width * 0.5 + 0.6), 0.0, 0.0)
