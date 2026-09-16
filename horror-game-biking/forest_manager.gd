@tool
extends Node3D


# ============================================================
# CONTAINER
# ============================================================

@export_group("Container")

@export var terrain_plane: NodePath

@export var trees_container: NodePath
@export var flowers_container: NodePath
@export var rocks_container: NodePath

@export var tree_scenes: Array[PackedScene] = []
@export var flower_scenes: Array[PackedScene] = []
@export var rock_scenes: Array[PackedScene] = []


# ============================================================
# WEG
# ============================================================

@export_group("Weg")

@export var main_road: Path3D
@export var road_branches: Array[Path3D] = []

@export var road_sample_distance: float = 1.0

@export var path_width: float = 2.4
@export var feather_amount: float = 1.2


# ============================================================
# WALD / VEGETATION
# ============================================================

@export_group("Wald + Vegetation")

@export var forest_bounds: Rect2 = Rect2(
	-60.0,
	-133.0,
	120.0,
	166.0
)

@export var tree_density_per_100m2: float = 8.0
@export var flower_density_per_100m2: float = 4.0
@export var rock_density_per_100m2: float = 2.0

@export var min_tree_spacing: float = 2.5

@export var min_tree_road_distance: float = 3.8
@export var max_tree_road_distance: float = 33.0

@export var min_vegetation_road_distance: float = 3.6
@export var max_vegetation_road_distance: float = 33.0

@export var max_spawn_attempts: int = 20000


# ============================================================
# CHUNKS
# ============================================================

@export_group("Vegetation Chunks")

@export var chunk_size: float = 25.0

@export_range(1, 10, 1)
var render_distance_chunks: int = 2

@export var player_path: NodePath


# ============================================================
# VARIATION
# ============================================================

@export_group("Variation")

@export var tree_scale_variance: float = 0.2

@export var random_rotation: bool = true


# ============================================================
# REBUILD
# ============================================================

@export_group("Aktionen")

@export var rebuild_now: bool = false:
	set(value):
		if value:
			call_deferred("rebuild_all")
		rebuild_now = false


# ============================================================
# INTERN
# ============================================================

const MAX_SHADER_SEGMENTS: int = 1024

var _rebuild_running := false

var _chunk_data: Dictionary = {}
var _active_chunks: Dictionary = {}
# PackedScene-Instanzen werden nur beim Rebuild analysiert.  Der Cache enthält
# alle sichtbaren Mesh-Parts samt Transform relativ zum Root der PackedScene.
var _mesh_part_cache: Dictionary = {}

var _last_player_chunk := Vector2i(
	999999,
	999999
)


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# Alte, im Editor serialisierte MultiMeshes werden sofort entfernt. Dadurch
	# kann vor dem ersten deferred Rebuild kein kompletter Wald gerendert werden.
	if not Engine.is_editor_hint():
		clear_generated_chunks()
	call_deferred("rebuild_all")


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:

	if Engine.is_editor_hint():
		return

	if player_path == NodePath():
		return

	var player := get_node_or_null(player_path)

	if player == null:
		return

	var player_position : Vector3 = player.global_position

	var current_chunk := world_to_chunk(
		Vector2(
			player_position.x,
			player_position.z
		)
	)

	if current_chunk == _last_player_chunk:
		return

	_last_player_chunk = current_chunk

	update_visible_chunks(current_chunk)


# ============================================================
# HAUPTFUNKTION
# ============================================================

func rebuild_all() -> void:

	if _rebuild_running:
		return

	_rebuild_running = true

	# Auch im Editor gespeicherte, zuvor erzeugte Chunk-Nodes dürfen beim
	# Spielstart nicht als kompletter Wald weiter sichtbar bleiben.
	clear_generated_chunks()
	_active_chunks.clear()
	_last_player_chunk = Vector2i(999999, 999999)

	update_road_shader()

	build_vegetation_data()

	# Im Editor zunächst alles anzeigen.
	# Im Spiel wird direkt auf den Spielerbereich reduziert.
	if Engine.is_editor_hint():

		var all_chunks := _get_all_chunk_coordinates()

		for chunk in all_chunks:
			activate_chunk(chunk)

	else:

		var player := get_node_or_null(player_path)

		if player != null:

			var player_chunk := world_to_chunk(
				Vector2(
					player.global_position.x,
					player.global_position.z
				)
			)

			_last_player_chunk = player_chunk

			update_visible_chunks(player_chunk)

	_rebuild_running = false

	print("WaldManager: Wegenetz + Chunk-Vegetation aktualisiert.")


# ============================================================
# CURVES
# ============================================================

func get_all_roads() -> Array[Curve3D]:

	var result: Array[Curve3D] = []

	if main_road != null and main_road.curve != null:

		if main_road.curve.point_count >= 2:
			result.append(main_road.curve)

	for branch in road_branches:

		if branch != null and branch.curve != null:

			if branch.curve.point_count >= 2:
				result.append(branch.curve)

	return result


# ============================================================
# KUBISCHE KURVE
# ============================================================

func cubic_point(
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	t: float
) -> Vector3:

	var t2 := t * t
	var t3 := t2 * t

	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func get_smooth_curve_points(
	curve: Curve3D
) -> Array[Vector3]:

	var result: Array[Vector3] = []

	if curve == null:
		return result

	var point_count := curve.point_count

	if point_count < 2:
		return result

	var samples_per_segment: int = 12

	for i in range(point_count - 1):

		var p0 := curve.get_point_position(
			maxi(i - 1, 0)
		)

		var p1 := curve.get_point_position(i)

		var p2 := curve.get_point_position(i + 1)

		var p3 := curve.get_point_position(
			mini(i + 2, point_count - 1)
		)

		for j in range(samples_per_segment):

			var t := float(j) / float(samples_per_segment)

			result.append(
				cubic_point(
					p0,
					p1,
					p2,
					p3,
					t
				)
			)

	result.append(
		curve.get_point_position(
			point_count - 1
		)
	)

	return result


# ============================================================
# ROAD SEGMENTS
# ============================================================

func get_road_segments() -> Array[Vector4]:

	var segments: Array[Vector4] = []

	for curve in get_all_roads():

		var points := get_smooth_curve_points(curve)

		if points.size() < 2:
			continue

		for i in range(points.size() - 1):

			if segments.size() >= MAX_SHADER_SEGMENTS:
				return segments

			var a := points[i]
			var b := points[i + 1]

			segments.append(
				Vector4(
					a.x,
					a.z,
					b.x,
					b.z
				)
			)

	return segments


# ============================================================
# SHADER
# ============================================================

func update_road_shader() -> void:

	var plane := get_node_or_null(terrain_plane)

	if plane == null:
		push_error("Terrain Plane nicht gefunden.")
		return

	if not plane is MeshInstance3D:
		push_error("terrain_plane muss ein MeshInstance3D sein.")
		return

	var mesh_instance := plane as MeshInstance3D

	var material := mesh_instance.get_active_material(0)

	if material == null:
		push_error("Der Terrain Plane hat kein Material.")
		return

	if not material is ShaderMaterial:
		push_error(
			"Das Material des Terrain Plane muss ein ShaderMaterial sein."
		)
		return

	var shader_material := material as ShaderMaterial

	var segments := get_road_segments()

	shader_material.set_shader_parameter(
		"road_segment_count",
		segments.size()
	)

	var packed_segments := PackedVector4Array()

	for segment in segments:
		packed_segments.append(segment)

	shader_material.set_shader_parameter(
		"road_segments",
		packed_segments
	)

	shader_material.set_shader_parameter(
		"path_width",
		path_width
	)

	shader_material.set_shader_parameter(
		"feather_amount",
		feather_amount
	)


# ============================================================
# DISTANCE ZUM WEG
# ============================================================

func distance_to_road(position: Vector2) -> float:

	var nearest := INF

	for curve in get_all_roads():

		var points := get_smooth_curve_points(curve)

		for point3 in points:

			var point := Vector2(
				point3.x,
				point3.z
			)

			var d := position.distance_to(point)

			if d < nearest:
				nearest = d

	return nearest


# ============================================================
# CHUNK KOORDINATE
# ============================================================

func world_to_chunk(position: Vector2) -> Vector2i:

	return Vector2i(
		floori(position.x / chunk_size),
		floori(position.y / chunk_size)
	)


func chunk_to_world(chunk: Vector2i) -> Vector2:

	return Vector2(
		chunk.x * chunk_size,
		chunk.y * chunk_size
	)


# ============================================================
# VEGETATION DATEN ERZEUGEN
# ============================================================

func build_vegetation_data() -> void:

	_chunk_data.clear()
	_mesh_part_cache.clear()
	cache_scene_mesh_parts(tree_scenes)
	cache_scene_mesh_parts(flower_scenes)
	cache_scene_mesh_parts(rock_scenes)

	generate_type_data(
		tree_scenes,
		tree_density_per_100m2,
		true
	)

	generate_type_data(
		flower_scenes,
		flower_density_per_100m2,
		false
	)

	generate_type_data(
		rock_scenes,
		rock_density_per_100m2,
		false
	)


# ============================================================
# EINEN VEGETATIONSTYP GENERIEREN
# ============================================================

func generate_type_data(
	scenes: Array[PackedScene],
	density: float,
	is_tree: bool
) -> void:

	if scenes.is_empty():
		return

	var area := forest_bounds.size.x * forest_bounds.size.y

	var target_count := int(
		area / 100.0 * density
	)

	if target_count <= 0:
		return

	var positions: Array[Vector2] = []

	var attempts := 0
	var placed := 0

	while placed < target_count:

		if attempts >= max_spawn_attempts:
			break

		attempts += 1

		var position := Vector2(
			randf_range(
				forest_bounds.position.x,
				forest_bounds.position.x +
				forest_bounds.size.x
			),
			randf_range(
				forest_bounds.position.y,
				forest_bounds.position.y +
				forest_bounds.size.y
			)
		)

		var road_distance := distance_to_road(position)

		if is_tree:

			if road_distance < min_tree_road_distance:
				continue

			if road_distance > max_tree_road_distance:
				continue

			var too_close := false

			for other in positions:

				if position.distance_to(other) < min_tree_spacing:
					too_close = true
					break

			if too_close:
				continue

		else:

			if road_distance < min_vegetation_road_distance:
				continue

			if road_distance > max_vegetation_road_distance:
				continue

		# position ist Manager-lokal, Chunks sind jedoch immer Weltkoordinaten.
		var world_position := to_global(Vector3(position.x, 0.0, position.y))
		var chunk := world_to_chunk(Vector2(world_position.x, world_position.z))

		if not _chunk_data.has(chunk):
			_chunk_data[chunk] = {
				"trees": [],
				"flowers": [],
				"rocks": []
			}

		var scene_index := randi() % scenes.size()

		var type_name := "trees" if is_tree else ""

		if not is_tree:
			type_name = "flowers"

		if not is_tree and scenes == rock_scenes:
			type_name = "rocks"

		var entry := {
			"position": position,
			"scene_index": scene_index,
			"rotation": randf_range(0.0, TAU) if random_rotation else 0.0,
			"scale_factor": 1.0 + randf_range(-tree_scale_variance, tree_scale_variance) if is_tree else 1.0
		}

		_chunk_data[chunk][type_name].append(entry)

		positions.append(position)

		placed += 1


# ============================================================
# SICHTBARE CHUNKS
# ============================================================

func update_visible_chunks(
	center: Vector2i
) -> void:

	var wanted: Dictionary = {}

	for x in range(
		-render_distance_chunks,
		render_distance_chunks + 1
	):

		for z in range(
			-render_distance_chunks,
			render_distance_chunks + 1
		):

			var chunk := Vector2i(
				center.x + x,
				center.y + z
			)

			wanted[chunk] = true

	# Nicht mehr benötigte Chunks entfernen.
	var active_keys := _active_chunks.keys()

	for chunk in active_keys:

		if not wanted.has(chunk):
			deactivate_chunk(chunk)

	# Neue Chunks aktivieren.
	for chunk in wanted.keys():

		if not _active_chunks.has(chunk):
			activate_chunk(chunk)


# ============================================================
# CHUNK AKTIVIEREN
# ============================================================

func activate_chunk(chunk: Vector2i) -> void:

	if _active_chunks.has(chunk):
		return

	if not _chunk_data.has(chunk):
		_active_chunks[chunk] = true
		return

	var data: Dictionary = _chunk_data[chunk]

	build_chunk_type(
		trees_container,
		tree_scenes,
		data["trees"],
		"Trees",
		chunk
	)

	build_chunk_type(
		flowers_container,
		flower_scenes,
		data["flowers"],
		"Flowers",
		chunk
	)

	build_chunk_type(
		rocks_container,
		rock_scenes,
		data["rocks"],
		"Rocks",
		chunk
	)

	_active_chunks[chunk] = true


# ============================================================
# CHUNK DEAKTIVIEREN
# ============================================================

func deactivate_chunk(chunk: Vector2i) -> void:

	var containers := [
		get_node_or_null(trees_container),
		get_node_or_null(flowers_container),
		get_node_or_null(rocks_container)
	]

	for container in containers:

		if container == null:
			continue

		for child in container.get_children():
			if child.has_meta("wald_manager_chunk") and child.get_meta("wald_manager_chunk") == chunk:
				child.queue_free()

	_active_chunks.erase(chunk)


# ============================================================
# CHUNK TYP BAUEN
# ============================================================

func build_chunk_type(
	container_path: NodePath,
	scenes: Array[PackedScene],
	entries: Array,
	label: String,
	chunk: Vector2i
) -> void:

	var container := get_node_or_null(container_path)

	if container == null:
		return

	if scenes.is_empty():
		return

	if entries.is_empty():
		return

	# Alle Mesh-Parts einer Scene bekommen eine eigene MultiMesh. Dadurch kann
	# ein Baum mit Stamm, Aesten und Blaettern als ein einziges Prop erscheinen.
	var mesh_groups: Dictionary = {}

	for entry in entries:

		var scene_index: int = entry["scene_index"]

		if scene_index < 0 or scene_index >= scenes.size():
			continue

		var meshes := get_cached_mesh_parts(scenes[scene_index])

		for mesh_data in meshes:

			var key := str(
				scene_index
			) + "_" + str(
				mesh_data["index"]
			)

			if not mesh_groups.has(key):
				mesh_groups[key] = {
					"mesh": mesh_data["mesh"],
					"local_transform": mesh_data["local_transform"],
					"instances": []
				}

			mesh_groups[key]["instances"].append(
				entry
			)

	# Für jedes Mesh ein MultiMesh.
	for key in mesh_groups:

		var group: Dictionary = mesh_groups[key]

		var mesh: Mesh = group["mesh"]
		var instances: Array = group["instances"]
		var local_transform: Transform3D = group["local_transform"]

		if mesh == null:
			continue

		var multi_mesh := MultiMesh.new()

		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.use_colors = false
		multi_mesh.use_custom_data = false
		multi_mesh.mesh = mesh
		multi_mesh.instance_count = instances.size()

		var multi_instance := MultiMeshInstance3D.new()

		multi_instance.multimesh = multi_mesh

		multi_instance.name = (
			"%d_%d_%s_%s"
			% [
				chunk.x,
				chunk.y,
				label,
				key
			]
		)

		container.add_child(multi_instance)
		multi_instance.set_meta("wald_manager_chunk", chunk)

		if Engine.is_editor_hint():
			multi_instance.owner = get_tree().edited_scene_root

		for i in range(instances.size()):
			var entry: Dictionary = instances[i]
			var pos: Vector2 = entry["position"]
			var prop_transform := Transform3D(
				Basis(Vector3.UP, entry["rotation"]).scaled(Vector3.ONE * entry["scale_factor"]),
				Vector3(pos.x, 0.0, pos.y)
			)
			# Manager- und Container-Transforms werden explizit einbezogen. So
			# bleiben Chunks Welt-koherent, auch wenn Container verschoben sind.
			var world_transform := global_transform * prop_transform * local_transform
			var transform: Transform3D = container.global_transform.affine_inverse() * world_transform
			multi_mesh.set_instance_transform(i, transform)


		if label == "Trees":
			var static_body := StaticBody3D.new()
			static_body.name = "%d_%d_Collision" % [chunk.x, chunk.y]
			container.add_child(static_body)
			static_body.set_meta("wald_manager_chunk", chunk)

			if Engine.is_editor_hint():
				static_body.owner = get_tree().edited_scene_root

			for i in range(instances.size()):
				var entry: Dictionary = instances[i]
				var pos: Vector2 = entry["position"]
				var scale_factor: float = entry["scale_factor"]
				var rot: float = entry["rotation"]

				var prop_transform := Transform3D(
					Basis(Vector3.UP, rot).scaled(Vector3.ONE * scale_factor),
					Vector3(pos.x, 0.0, pos.y)
				)
				var world_transform := global_transform * prop_transform
				var local_body_transform := static_body.global_transform.affine_inverse() * world_transform

				var collision_shape := CollisionShape3D.new()
				var cylinder := CylinderShape3D.new()
				cylinder.radius = 0.3 * scale_factor * 0.90
				cylinder.height = 4.5 * scale_factor
				collision_shape.shape = cylinder
				collision_shape.transform = local_body_transform.translated(Vector3(0.0, (4.5 * scale_factor) * 0.5, 0.0))
				static_body.add_child(collision_shape)

				if Engine.is_editor_hint():
					collision_shape.owner = get_tree().edited_scene_root


			# Für jeden aktiven Chunk eine dichte Nebelwand / Barriere am äußeren Rand erzeugen
			var world_pos := chunk_to_world(chunk)
			var half_size := chunk_size * 0.5

			# Physik-Barriere als Außenbegrenzung
			var boundary_body := StaticBody3D.new()
			boundary_body.name = "%d_%d_BoundaryWall" % [chunk.x, chunk.y]
			container.add_child(boundary_body)
			boundary_body.set_meta("wald_manager_chunk", chunk)

			if Engine.is_editor_hint():
				boundary_body.owner = get_tree().edited_scene_root

			var box_shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(chunk_size, 10.0, 1.0)
			box_shape.shape = box
			box_shape.position = Vector3(half_size, 5.0, half_size)
			boundary_body.add_child(box_shape)

			if Engine.is_editor_hint():
				box_shape.owner = get_tree().edited_scene_root

			# Visueller FogVolume-Block als undurchdringliche Nebelwand
			var fv := FogVolume.new()
			fv.name = "%d_%d_FogWall" % [chunk.x, chunk.y]
			var fv_material := FogMaterial.new()
			fv_material.density = 12.0
			fv_material.albedo = Color(0.0, 0.0, 0.0, 1)
			fv.material = fv_material
			fv.size = Vector3(chunk_size, 8.0, 2.0)
			fv.position = Vector3(half_size, 4.0, half_size)
			container.add_child(fv)
			fv.set_meta("wald_manager_chunk", chunk)

			if Engine.is_editor_hint():
				fv.owner = get_tree().edited_scene_root


# ============================================================
# ALLE MESHES EINER SCENE
# ============================================================

func cache_scene_mesh_parts(scenes: Array[PackedScene]) -> void:
	for scene in scenes:
		get_cached_mesh_parts(scene)


func get_cached_mesh_parts(scene: PackedScene) -> Array:
	if scene == null:
		return []

	var cache_key := scene.get_instance_id()
	if _mesh_part_cache.has(cache_key):
		return _mesh_part_cache[cache_key]

	var result := get_meshes_from_scene(scene)
	_mesh_part_cache[cache_key] = result
	return result


func get_meshes_from_scene(
	scene: PackedScene
) -> Array:

	var result: Array = []

	if scene == null:
		return result

	var instance := scene.instantiate()

	collect_meshes(
		instance,
		result,
		Transform3D.IDENTITY,
		true
	)

	instance.free()

	return result


func collect_meshes(
	node: Node,
	result: Array,
	parent_transform: Transform3D,
	is_scene_root: bool
) -> void:
	var local_transform := parent_transform
	if node is Node3D and not is_scene_root:
		local_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D:

		var mesh_instance := node as MeshInstance3D

		# Unsichtbare Parts der Original-PackedScene gehoeren nicht in die MultiMesh.
		if mesh_instance.mesh != null and mesh_instance.visible:

			result.append({
				"mesh": mesh_instance.mesh,
				"index": result.size(),
				"local_transform": local_transform
			})

	for child in node.get_children():

		collect_meshes(
			child,
			result,
			local_transform,
			false
		)
		if child is MultiMeshInstance3D or child is StaticBody3D or child is FogVolume:
			child.free()



func clear_generated_chunks() -> void:
	var containers := [
		get_node_or_null(trees_container),
		get_node_or_null(flowers_container),
		get_node_or_null(rocks_container)
	]
	for container in containers:
		if container == null:
			continue
		for child in container.get_children():
			if child is MultiMeshInstance3D or child is StaticBody3D:
				child.free()


# ============================================================
# ALLE CHUNKS
# ============================================================

func _get_all_chunk_coordinates() -> Array:
	# Die Daten sind bereits nach Welt-Chunks organisiert. Das funktioniert auch,
	# wenn der Manager relativ zum Weltursprung verschoben wurde.
	return _chunk_data.keys()
