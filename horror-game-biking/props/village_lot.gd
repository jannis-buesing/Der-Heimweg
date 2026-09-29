@tool
extends Node3D

enum LotPreset { CUSTOM, MODERN_FAMILY, OLD_COTTAGE, ABANDONED_HOUSE, INHABITED_VILLA }

@export_group("Lot Configuration")
@export var preset: LotPreset = LotPreset.CUSTOM:
	set(value):
		preset = value
		_apply_preset()

@export var lot_width: float = 16.0:
	set(value):
		lot_width = max(10.0, value)
		_update_lot()

@export var lot_depth: float = 20.0:
	set(value):
		lot_depth = max(12.0, value)
		_update_lot()

@export_group("Yard Props & Decor")
@export var has_fence: bool = true:
	set(value):
		has_fence = value
		_update_lot()

@export var has_mailbox: bool = true:
	set(value):
		has_mailbox = value
		_update_lot()

@export var has_trash_bins: bool = true:
	set(value):
		has_trash_bins = value
		_update_lot()

@export var has_garden_lamp: bool = true:
	set(value):
		has_garden_lamp = value
		_update_lot()

@export var has_garden_furniture: bool = false:
	set(value):
		has_garden_furniture = value
		_update_lot()

@export var has_woodpile: bool = false:
	set(value):
		has_woodpile = value
		_update_lot()

@export_group("Vegetation & Randomization")
@export var has_garden_bushes: bool = true:
	set(value):
		has_garden_bushes = value
		_update_lot()

@export_range(0.0, 1.0, 0.05) var vegetation_density: float = 0.5:
	set(value):
		vegetation_density = value
		_update_lot()

@export var randomize_lot: bool = false:
	set(value):
		if value:
			randomize_all()
		randomize_lot = false

# Internal Nodes
@onready var ground_mesh: MeshInstance3D = get_node_or_null("Ground")
@onready var path_mesh: MeshInstance3D = get_node_or_null("Pathway")
@onready var driveway_mesh: MeshInstance3D = get_node_or_null("Driveway")
@onready var house_node: Node3D = get_node_or_null("House")

@onready var fence_node: Node3D = get_node_or_null("Fence")
@onready var mailbox_node: Node3D = get_node_or_null("Mailbox")
@onready var trash_bins_node: Node3D = get_node_or_null("TrashBins")
@onready var bushes_node: Node3D = get_node_or_null("Bushes")
@onready var garden_lamp_node: Node3D = get_node_or_null("GardenLamp")
@onready var furniture_node: Node3D = get_node_or_null("GardenFurniture")
@onready var woodpile_node: Node3D = get_node_or_null("WoodPile")


func _ready() -> void:
	_update_lot()


func randomize_all(custom_seed: int = -1) -> void:
	if custom_seed >= 0:
		seed(custom_seed)
	
	has_fence = (randf() > 0.3)
	has_mailbox = (randf() > 0.2)
	has_trash_bins = (randf() > 0.3)
	has_garden_bushes = (randf() > 0.2)
	has_garden_lamp = (randf() > 0.4)
	has_garden_furniture = (randf() > 0.6)
	has_woodpile = (randf() > 0.5)
	vegetation_density = randf_range(0.2, 0.8)
	
	if house_node != null and house_node.has_method("randomize_house"):
		house_node.call("randomize_house", custom_seed)
	
	_update_lot()


func _apply_preset() -> void:
	if preset == LotPreset.CUSTOM:
		return
	
	if house_node == null:
		return
	
	match preset:
		LotPreset.MODERN_FAMILY:
			has_fence = true
			has_mailbox = true
			has_trash_bins = true
			has_garden_bushes = true
			has_garden_lamp = true
			has_garden_furniture = true
			has_woodpile = false
			vegetation_density = 0.6
			if house_node.has_method("set"):
				house_node.set("stories", 2)
				house_node.set("roof_type", 0) # GABLE
				house_node.set("wall_color", 0) # CREAM
				house_node.set("garage_position", 1) # LEFT
				house_node.set("ground_window_state", 1) # LIT
				house_node.set("upper_window_state", 1) # LIT
		
		LotPreset.OLD_COTTAGE:
			has_fence = true
			has_mailbox = true
			has_trash_bins = false
			has_garden_bushes = true
			has_garden_lamp = false
			has_garden_furniture = true
			has_woodpile = true
			vegetation_density = 0.8
			if house_node.has_method("set"):
				house_node.set("stories", 1)
				house_node.set("roof_type", 1) # HIP
				house_node.set("wall_color", 1) # BRICK_RED
				house_node.set("garage_position", 0) # NONE
				house_node.set("has_extension", true)
				house_node.set("ground_window_state", 2) # CURTAIN
		
		LotPreset.ABANDONED_HOUSE:
			has_fence = false
			has_mailbox = false
			has_trash_bins = true
			has_garden_bushes = true
			has_garden_lamp = false
			has_garden_furniture = false
			has_woodpile = true
			vegetation_density = 0.9
			if house_node.has_method("set"):
				house_node.set("stories", 2)
				house_node.set("wall_color", 2) # DARK_WOOD
				house_node.set("roof_color", 2) # CHARCOAL
				house_node.set("ground_window_state", 0) # DARK
				house_node.set("upper_window_state", 0) # DARK
		
		LotPreset.INHABITED_VILLA:
			has_fence = true
			has_mailbox = true
			has_trash_bins = true
			has_garden_bushes = true
			has_garden_lamp = true
			has_garden_furniture = true
			has_woodpile = false
			vegetation_density = 0.5
			if house_node.has_method("set"):
				house_node.set("stories", 2)
				house_node.set("roof_type", 3) # MANSARD
				house_node.set("wall_color", 3) # BLUE_GRAY
				house_node.set("garage_position", 2) # RIGHT
				house_node.set("ground_window_state", 3) # INHABITED
				house_node.set("upper_window_state", 1) # LIT
				house_node.set("person_silhouette", 1) # STANDING
	
	_update_lot()


func _update_lot() -> void:
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.18, 0.28, 0.15)
	grass_mat.roughness = 0.9
	
	var path_mat = StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.40, 0.38, 0.35)
	path_mat.roughness = 0.85
	
	if ground_mesh:
		ground_mesh.material_override = grass_mat
		if ground_mesh.mesh is BoxMesh:
			(ground_mesh.mesh as BoxMesh).size = Vector3(lot_width, 0.04, lot_depth)
	
	if path_mesh:
		path_mesh.material_override = path_mat
	
	if driveway_mesh:
		driveway_mesh.material_override = path_mat
	
	if fence_node:
		fence_node.visible = has_fence
	
	if mailbox_node:
		mailbox_node.visible = has_mailbox
	
	if trash_bins_node:
		trash_bins_node.visible = has_trash_bins
	
	if bushes_node:
		bushes_node.visible = has_garden_bushes
		for child in bushes_node.get_children():
			child.visible = (randf() <= vegetation_density * 1.2)
	
	if garden_lamp_node:
		garden_lamp_node.visible = has_garden_lamp
	
	if furniture_node:
		furniture_node.visible = has_garden_furniture
	
	if woodpile_node:
		woodpile_node.visible = has_woodpile
