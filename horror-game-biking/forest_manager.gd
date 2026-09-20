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


# ============================================================
# FOG
# ============================================================

@export_group("Weg-Fog")

## Beginn des Fog-Bereichs neben dem Weg.
## Entspricht ungefähr dem Abstand, ab dem die Vegetation beginnt.
@export var min_fog_road_distance: float = 3.8

## Äußerer Rand des Fog-Bereichs.
## Danach soll praktisch nichts mehr durch den Wald sichtbar sein.
@export var max_fog_road_distance: float = 20.0

## Höhe des volumetrischen Fog-Bereichs.
## Der Bereich reicht vom fog_bottom bis fog_bottom + fog_height.
@export var fog_height: float = 20.0

## Unterhalb des Wegniveaus beginnen, damit kein sichtbarer Spalt am Boden entsteht.
@export var fog_bottom: float = -1.0

## Maximale Fog-Dichte am äußeren Rand.
@export_range(0.0, 5.0, 0.01) var fog_strength: float = 1.0

## Form des seitlichen Übergangs.
## Höher = länger schwach und erst weiter außen stark.
@export_range(0.5, 4.0, 0.05) var fog_gradient_power: float = 1.8

## Kleiner Übergangsbereich an den Enden eines Fog-Abschnitts.
## Verhindert sichtbare Linien zwischen den einzelnen Volumes.
@export_range(0.01, 0.2, 0.005) var fog_segment_fade: float = 0.04

@export var fog_container: NodePath

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

# PackedScene-Instanzen werden nur beim Rebuild analysiert.
# Der Cache enthält alle sichtbaren Mesh-Parts samt Transform
# relativ zum Root der PackedScene.
var _mesh_part_cache: Dictionary = {}

var _last_player_chunk := Vector2i(
	999999,
	999999
)


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# Alte, im Editor serialisierte MultiMeshes werden sofort entfernt.
	if Engine.is_editor_hint(): call_deferred("rebuild_all")


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

	var player_position: Vector3 = player.global_position

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

	clear_generated_chunks()

	_active_chunks.clear()

	_last_player_chunk = Vector2i(
		999999,
		999999
	)

	update_road_shader()

	build_vegetation_data()

	build_fog_volumes()

	# Im Editor zunächst alles anzeigen.
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

	print(
		"WaldManager: Wegenetz + Chunk-Vegetation + Fog aktualisiert."
	)


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
		push_error(
			"terrain_plane muss ein MeshInstance3D sein."
		)
		return

	var mesh_instance := plane as MeshInstance3D

	var material := mesh_instance.get_active_material(0)

	if material == null:
		push_error(
			"Der Terrain Plane hat kein Material."
		)
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
# FOG SHADER
# ============================================================

func create_fog_shader() -> Shader:

	var shader := Shader.new()

	shader.code = """
shader_type fog;

uniform float fog_strength = 1.0;
uniform float fog_gradient_power = 1.8;
uniform float fog_segment_fade = 0.04;
uniform float side_sign = 1.0;

void fog() {

	// --------------------------------------------------------
	// X = seitliche Richtung des FogVolumes
	//
	// UVW.x läuft von 0 bis 1 durch die Fog-Breite.
	// Durch side_sign wird für die linke Seite die Richtung
	// einfach gespiegelt.
	// --------------------------------------------------------

	float lateral_position =
		clamp(
			UVW.x * side_sign +
			(1.0 - side_sign) * 0.5,
			0.0,
			1.0
		);

	// Weicher Anstieg vom Weg nach außen.
	float lateral_density =
		1.0 - smoothstep(0.0, 1.0, lateral_position);

	lateral_density =
		pow(lateral_density, fog_gradient_power);

	// --------------------------------------------------------
	// Längsrichtung:
	//
	// Die einzelnen Volumes treffen genau aneinander.
	// An jedem Ende fällt die Dichte nur auf 50 % ab.
	// Das nächste Volume beginnt ebenfalls bei 50 %.
	//
	// Dadurch ergibt sich an der gemeinsamen Grenze:
	//
	// 0.5 + 0.5 = 1.0
	//
	// Es entsteht keine sichtbare harte Linie zwischen
	// den einzelnen Fog-Abschnitten.
	// --------------------------------------------------------

	float fade =
		clamp(
			fog_segment_fade,
			0.001,
			0.25
		);

	float start_factor =
		0.5 +
		0.5 *
		smoothstep(
			0.0,
			fade,
			UVW.z
		);

	float end_factor =
		1.0 -
		0.5 *
		smoothstep(
			1.0 - fade,
			1.0,
			UVW.z
		);

	float longitudinal_factor =
		min(
			start_factor,
			end_factor
		);

	DENSITY =
		fog_strength *
		lateral_density *
		longitudinal_factor;
}
"""

	return shader


# ============================================================
# FOG VOLUMES
# ============================================================

func create_end_fog_shader() -> Shader:

	var shader := Shader.new()

	shader.code = """
shader_type fog;

uniform float fog_strength = 1.0;
uniform float fog_segment_fade = 0.04;

void fog() {

	float fade =
		clamp(
			fog_segment_fade,
			0.001,
			0.25
		);

	float start_factor =
		0.5 +
		0.5 *
		smoothstep(
			0.0,
			fade,
			UVW.z
		);

	float end_factor =
		1.0 -
		0.5 *
		smoothstep(
			1.0 - fade,
			1.0,
			UVW.z
		);

	float longitudinal_factor =
		min(
			start_factor,
			end_factor
		);

	DENSITY =
		fog_strength *
		longitudinal_factor;
}
"""

	return shader


func build_fog_volumes() -> void:

	var container := get_node_or_null(fog_container)

	if container == null:
		push_error(
			"ForestManager: fog_container ist nicht gesetzt."
		)
		return

	if max_fog_road_distance <= min_fog_road_distance:
		push_error(
			"ForestManager: max_fog_road_distance muss größer als min_fog_road_distance sein."
		)
		return

	if fog_height <= 0.0:
		push_error(
			"ForestManager: fog_height muss größer als 0 sein."
		)
		return

	var shader := create_fog_shader()
	var end_shader := create_end_fog_shader()

	var created_count := 0
	var end_created_count := 0

	for curve in get_all_roads():

		var points := get_smooth_curve_points(curve)

		if points.size() < 2:
			continue

		# ========================================================
		# SEITLICHER FOG ENTLANG DES WEGES
		# ========================================================

		for side in [-1.0, 1.0]:

			for i in range(points.size() - 1):

				var p0 := points[i]
				var p1 := points[i + 1]

				var flat_segment := Vector3(
					p1.x - p0.x,
					0.0,
					p1.z - p0.z
				)

				var segment_length := flat_segment.length()

				if segment_length < 0.05:
					continue

				var direction := flat_segment.normalized()

				var right := Vector3(
					direction.z,
					0.0,
					-direction.x
				).normalized()

				var outward: Vector3 = right * side

				var center_distance := (
					min_fog_road_distance +
					max_fog_road_distance
				) * 0.5

				var center: Vector3 = (
					(p0 + p1) * 0.5
					+ outward * center_distance
				)

				center.y += (
					fog_bottom +
					fog_height * 0.5
				)

				var fog := FogVolume.new()

				fog.name = "RoadFog_%d_%d_%d" % [
					created_count,
					i,
					int(side)
				]

				fog.size = Vector3(
					max_fog_road_distance -
					min_fog_road_distance,
					fog_height,
					segment_length + 4.0
				)

				var material := ShaderMaterial.new()

				material.shader = shader

				material.set_shader_parameter(
					"fog_strength",
					fog_strength
				)

				material.set_shader_parameter(
					"fog_gradient_power",
					fog_gradient_power
				)

				material.set_shader_parameter(
					"fog_segment_fade",
					fog_segment_fade
				)

				material.set_shader_parameter(
					"side_sign",
					side
				)

				fog.material = material

				container.add_child(fog)

				fog.global_position = center

				fog.global_basis = Basis.looking_at(
					direction,
					Vector3.UP
				)

				if Engine.is_editor_hint():

					var edited_root := get_tree().edited_scene_root

					if edited_root != null:
						fog.owner = edited_root

				created_count += 1

		# ========================================================
		# DEAD-END / HALBKREIS
		# ========================================================
		#
		# Am Ende jeder Straße wird der gleiche Fog wie an den
		# Seiten in einem Halbkreis weitergeführt.
		#
		# Der Halbkreis besteht aus mehreren überlappenden
		# "Kuchenscheiben". Jede Scheibe ist radial ausgerichtet.
		#
		# Dadurch entsteht keine Fog-Wand, sondern eine natürliche
		# Nebelzone, die dem Straßenende folgt.
		# ========================================================

		var end_p0 := points[points.size() - 2]
		var end_p1 := points[points.size() - 1]

		var end_segment := Vector3(
			end_p1.x - end_p0.x,
			0.0,
			end_p1.z - end_p0.z
		)

		if end_segment.length() >= 0.05:

			var end_direction := end_segment.normalized()

			# Mittelpunkt des Halbkreises.
			var end_center := Vector3(
				end_p1.x,
				0.0,
				end_p1.z
			)

			# Anzahl der Fog-Scheiben im Halbkreis.
			# Mehr Scheiben = sauberere Rundung.
			var arc_segments := 16

			# Der Halbkreis läuft von der linken zur rechten
			# Seite des Straßenendes.
			#
			# Der Winkel 0 zeigt in Fahrtrichtung.
			# Der Halbkreis liegt hinter dem Straßenende.
			var forward_angle := atan2(
				end_direction.z,
				end_direction.x
			)

			for arc_index in range(arc_segments):

				var t0 := float(arc_index) / float(arc_segments)
				var t1 := float(arc_index + 1) / float(arc_segments)

				var angle0 := forward_angle + PI * 1.5 + t0 * PI
				var angle1 := forward_angle + PI * 1.5 + t1 * PI

				var mid_angle := (angle0 + angle1) * 0.5

				# Radiale Richtung der aktuellen Fog-Scheibe.
				var radial := Vector3(
					cos(mid_angle),
					0.0,
					sin(mid_angle)
				)

				# Tangentiale Richtung entlang des Halbkreises.
				var tangent := Vector3(
					-radial.z,
					0.0,
					radial.x
				)

				var radial_width := (
					max_fog_road_distance -
					min_fog_road_distance
				)

				# Winkelbreite der Scheibe wird in eine ungefähre
				# Tangentiallänge umgerechnet.
				var arc_radius := (
					min_fog_road_distance +
					max_fog_road_distance
				) * 0.5

				var arc_length := (
					PI /
					float(arc_segments)
				) * arc_radius

				# Etwas Überlappung, damit zwischen den Scheiben
				# keine sichtbaren Schlitze entstehen.
				arc_length += 1.0

				var center_distance := (
					min_fog_road_distance +
					max_fog_road_distance
				) * 0.5

				var fog_center := (
					end_center +
					radial * center_distance
				)

				fog_center.y += (
					fog_bottom +
					fog_height * 0.5
				)

				var fog := FogVolume.new()

				fog.name = "RoadFog_DeadEnd_%d_%d" % [
					end_created_count,
					arc_index
				]

				# X = radialer Fog-Verlauf
				# Z = Tangente der Halbkreis-Scheibe
				fog.size = Vector3(
					radial_width,
					fog_height,
					arc_length
				)

				var material := ShaderMaterial.new()

				material.shader = shader

				material.set_shader_parameter(
					"fog_strength",
					fog_strength
				)

				material.set_shader_parameter(
					"fog_gradient_power",
					fog_gradient_power
				)

				material.set_shader_parameter(
					"fog_segment_fade",
					fog_segment_fade
				)

				# Verlauf vom Straßenende nach außen.
				material.set_shader_parameter(
					"side_sign",
					1.0
				)

				fog.material = material

				container.add_child(fog)

				fog.global_position = fog_center

				# Z zeigt tangential zum Halbkreis.
				# Dadurch liegt X radial und der Fog-Verlauf
				# geht vom Weg nach außen.
				fog.global_basis = Basis.looking_at(
					tangent,
					Vector3.UP
				)

				if Engine.is_editor_hint():

					var edited_root := get_tree().edited_scene_root

					if edited_root != null:
						fog.owner = edited_root

				end_created_count += 1

	print(
		"ForestManager: %d seitliche FogVolumes + %d Dead-End-FogVolumes erstellt."
		% [
			created_count,
			end_created_count
		]
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

	var area := (
		forest_bounds.size.x *
		forest_bounds.size.y
	)

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

		# position ist Manager-lokal.
		# Chunks werden jedoch anhand der Weltkoordinaten bestimmt.
		var world_position := to_global(
			Vector3(
				position.x,
				0.0,
				position.y
			)
		)

		var chunk := world_to_chunk(
			Vector2(
				world_position.x,
				world_position.z
			)
		)

		if not _chunk_data.has(chunk):

			_chunk_data[chunk] = {
				"trees": [],
				"flowers": [],
				"rocks": []
			}

		var scene_index := randi() % scenes.size()

		var type_name := "trees"

		if not is_tree:
			type_name = "flowers"

		if not is_tree and scenes == rock_scenes:
			type_name = "rocks"

		var entry := {
			"position": position,
			"scene_index": scene_index,
			"rotation":
				randf_range(0.0, TAU)
				if random_rotation
				else 0.0,
			"scale_factor":
				1.0 +
				randf_range(
					-tree_scale_variance,
					tree_scale_variance
				)
				if is_tree
				else 1.0
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

			if (
				child.has_meta("wald_manager_chunk")
				and
				child.get_meta("wald_manager_chunk") == chunk
			):
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

	# Alle Mesh-Parts einer Scene bekommen eine eigene MultiMesh.
	var mesh_groups: Dictionary = {}

	for entry in entries:

		var scene_index: int = entry["scene_index"]

		if scene_index < 0 or scene_index >= scenes.size():
			continue

		var meshes := get_cached_mesh_parts(
			scenes[scene_index]
		)

		for mesh_data in meshes:

			var key := (
				str(scene_index)
				+
				"_"
				+
				str(mesh_data["index"])
			)

			if not mesh_groups.has(key):

				mesh_groups[key] = {
					"mesh": mesh_data["mesh"],
					"local_transform":
						mesh_data["local_transform"],
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

		var local_transform: Transform3D = (
			group["local_transform"]
		)

		if mesh == null:
			continue

		var multi_mesh := MultiMesh.new()

		multi_mesh.transform_format = (
			MultiMesh.TRANSFORM_3D
		)

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

		multi_instance.set_meta(
			"wald_manager_chunk",
			chunk
		)

		if Engine.is_editor_hint():

			multi_instance.owner = (
				get_tree().edited_scene_root
			)

		for i in range(instances.size()):

			var entry: Dictionary = instances[i]

			var pos: Vector2 = entry["position"]

			var instance_transform := Transform3D(
				Basis(
					Vector3.UP,
					entry["rotation"]
				).scaled(
					Vector3.ONE *
					entry["scale_factor"]
				),
				Vector3(
					pos.x,
					0.0,
					pos.y
				)
			)

			# Manager- und Container-Transforms
			# werden explizit berücksichtigt.
			var world_transform: Transform3D = (
				global_transform *
				instance_transform *
				local_transform
			)

			var transform: Transform3D = (
				container.global_transform
				.affine_inverse() *
				world_transform
			)

			multi_mesh.set_instance_transform(
				i,
				transform
			)

		if label == "Trees":

			var static_body := StaticBody3D.new()

			static_body.name = (
				"%d_%d_Collision"
				% [
					chunk.x,
					chunk.y
				]
			)

			container.add_child(static_body)

			static_body.set_meta(
				"wald_manager_chunk",
				chunk
			)

			if Engine.is_editor_hint():

				static_body.owner = (
					get_tree().edited_scene_root
				)

			for i in range(instances.size()):

				var entry: Dictionary = instances[i]

				var pos: Vector2 = entry["position"]

				var scale_factor: float = (
					entry["scale_factor"]
				)

				var rot: float = entry["rotation"]

				var prop_transform := Transform3D(
					Basis(
						Vector3.UP,
						rot
					).scaled(
						Vector3.ONE *
						scale_factor
					),
					Vector3(
						pos.x,
						0.0,
						pos.y
					)
				)

				var world_transform := (
					global_transform *
					prop_transform
				)

				var local_body_transform := (
					static_body.global_transform
					.affine_inverse() *
					world_transform
				)

				var collision_shape := CollisionShape3D.new()

				var cylinder := CylinderShape3D.new()

				cylinder.radius = (
					0.3 *
					scale_factor *
					0.90
				)

				cylinder.height = (
					4.5 *
					scale_factor
				)

				collision_shape.shape = cylinder

				collision_shape.transform = (
					local_body_transform.translated(
						Vector3(
							0.0,
							(
								4.5 *
								scale_factor
							) *
							0.5,
							0.0
						)
					)
				)

				static_body.add_child(
					collision_shape
				)

				if Engine.is_editor_hint():

					collision_shape.owner = (
						get_tree().edited_scene_root
					)


# ============================================================
# ALLE MESHES EINER SCENE
# ============================================================

func cache_scene_mesh_parts(
	scenes: Array[PackedScene]
) -> void:

	for scene in scenes:
		get_cached_mesh_parts(scene)


func get_cached_mesh_parts(
	scene: PackedScene
) -> Array:

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

		local_transform = (
			parent_transform *
			(node as Node3D).transform
		)

	if node is MeshInstance3D:

		var mesh_instance := (
			node as MeshInstance3D
		)

		# Unsichtbare Parts werden nicht übernommen.
		if (
			mesh_instance.mesh != null
			and
			mesh_instance.visible
		):

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


# ============================================================
# GENERIERTE NODES LÖSCHEN
# ============================================================

func clear_generated_chunks() -> void:

	var containers := [
		get_node_or_null(trees_container),
		get_node_or_null(flowers_container),
		get_node_or_null(rocks_container),
		get_node_or_null(fog_container)
	]

	for container in containers:

		if container == null:
			continue

		for child in container.get_children():

			if (
				child is MultiMeshInstance3D
				or
				child is StaticBody3D
				or
				child is FogVolume
				or
				child is MeshInstance3D
			):

				child.free()


# ============================================================
# ALLE CHUNKS
# ============================================================

func _get_all_chunk_coordinates() -> Array:

	# Die Daten sind bereits nach Welt-Chunks organisiert.
	return _chunk_data.keys()
