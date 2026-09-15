@tool
extends StaticBody3D

enum GrassTone { FOREST_DARK, MUTED_GREEN, DRY_BROWN, LUSH_GREEN }

@export var field_size: Vector2 = Vector2(20.0, 20.0):
	set(value):
		field_size = value
		_update_mesh()

@export var tone: GrassTone = GrassTone.FOREST_DARK:
	set(value):
		tone = value
		_update_material()

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")


func _ready() -> void:
	_update_mesh()
	_update_material()


func _update_mesh() -> void:
	if mesh_instance and mesh_instance.mesh is BoxMesh:
		var box = mesh_instance.mesh as BoxMesh
		box.size = Vector3(field_size.x, 0.2, field_size.y)
		mesh_instance.position.y = -0.1
	
	if collision_shape and collision_shape.shape is BoxShape3D:
		var box = collision_shape.shape as BoxShape3D
		box.size = Vector3(field_size.x, 0.2, field_size.y)
		collision_shape.position.y = -0.1


func _update_material() -> void:
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.95
	match tone:
		GrassTone.FOREST_DARK:
			mat.albedo_color = Color(0.12, 0.18, 0.11)
		GrassTone.MUTED_GREEN:
			mat.albedo_color = Color(0.18, 0.24, 0.16)
		GrassTone.DRY_BROWN:
			mat.albedo_color = Color(0.24, 0.21, 0.15)
		GrassTone.LUSH_GREEN:
			mat.albedo_color = Color(0.15, 0.28, 0.14)
	
	if mesh_instance:
		mesh_instance.material_override = mat
