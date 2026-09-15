class_name Interactable
extends Node3D

signal interacted()

@export var is_interactable: bool = true
@export var prompt_text: String = "Benutzen"
@export var is_small_item: bool = false # Erhält dezenten Schimmer auf mittlere Distanz
@export var highlight_meshes: Array[MeshInstance3D] = []

var _original_materials: Dictionary = {}
var _is_focused: bool = false
var _is_shimmering: bool = false
var _shimmer_time: float = 0.0


func _ready() -> void:
	add_to_group("interactables")
	# Falls keine Meshes explizit angegeben wurden, suche automatisch Meshes unter diesem Knoten
	if highlight_meshes.is_empty():
		_find_meshes(self)
	_cache_materials()


func _find_meshes(node: Node) -> void:
	if node is MeshInstance3D and not highlight_meshes.has(node):
		highlight_meshes.append(node)
	for child in node.get_children():
		_find_meshes(child)


func _cache_materials() -> void:
	for mesh in highlight_meshes:
		if mesh:
			var mat = mesh.get_surface_override_material(0)
			if not mat and mesh.mesh and mesh.mesh.material:
				mat = mesh.mesh.material
			if mat:
				_original_materials[mesh] = mat.duplicate()


func _process(delta: float) -> void:
	if not is_interactable:
		if _is_shimmering or _is_focused:
			set_focus(false)
			set_shimmer(false)
		return

	if _is_shimmering and is_small_item and not _is_focused:
		_shimmer_time += delta * 2.5
		var glow = (sin(_shimmer_time) * 0.5 + 0.5) * 0.35 + 0.15
		for mesh in highlight_meshes:
			if mesh:
				var mat = mesh.get_surface_override_material(0)
				if mat is StandardMaterial3D:
					mat.emission_enabled = true
					mat.emission = Color(0.85, 0.9, 1.0)
					mat.emission_energy_multiplier = glow


func interact() -> void:
	if is_interactable:
		interacted.emit()


func set_focus(active: bool) -> void:
	if _is_focused == active:
		return
	_is_focused = active
	for mesh in highlight_meshes:
		if not mesh:
			continue
		if active:
			var mat = mesh.get_surface_override_material(0)
			if not mat:
				mat = StandardMaterial3D.new()
				if _original_materials.has(mesh):
					mat = _original_materials[mesh].duplicate()
				mesh.set_surface_override_material(0, mat)
			if mat is StandardMaterial3D:
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.95, 0.75)
				mat.emission_energy_multiplier = 0.6
		else:
			_restore_material(mesh)


func set_shimmer(active: bool) -> void:
	if _is_shimmering == active:
		return
	_is_shimmering = active
	if not active and not _is_focused:
		for mesh in highlight_meshes:
			_restore_material(mesh)


func _restore_material(mesh: MeshInstance3D) -> void:
	if not mesh:
		return
	if _original_materials.has(mesh):
		mesh.set_surface_override_material(0, _original_materials[mesh].duplicate())
	else:
		mesh.set_surface_override_material(0, null)
