@tool
extends StaticBody3D

enum BodyStyle { SEDAN, HATCHBACK, STATION_WAGON, PICKUP }
enum PaintColor { CRIMSON_RED, NAVY_BLUE, CHARCOAL_BLACK, SILVER_GRAY, FOREST_GREEN, VINTAGE_WHITE }

@export var body_style: BodyStyle = BodyStyle.SEDAN:
	set(value):
		body_style = value
		_update_car_mesh()

@export var paint_color: PaintColor = PaintColor.CRIMSON_RED:
	set(value):
		paint_color = value
		_update_paint()

@export var headlights_on: bool = false:
	set(value):
		headlights_on = value
		_update_lights()

@export var taillights_on: bool = false:
	set(value):
		taillights_on = value
		_update_lights()

@onready var lower_body: MeshInstance3D = get_node_or_null("LowerBody")
@onready var cabin_sedan: MeshInstance3D = get_node_or_null("CabinSedan")
@onready var cabin_wagon: MeshInstance3D = get_node_or_null("CabinWagon")
@onready var cabin_pickup: MeshInstance3D = get_node_or_null("CabinPickup")
@onready var pickup_bed: MeshInstance3D = get_node_or_null("PickupBed")

@onready var headlight_l: SpotLight3D = get_node_or_null("Lights/HeadlightL")
@onready var headlight_r: SpotLight3D = get_node_or_null("Lights/HeadlightR")
@onready var head_lens_l: MeshInstance3D = get_node_or_null("Lights/HeadLensL")
@onready var head_lens_r: MeshInstance3D = get_node_or_null("Lights/HeadLensR")

@onready var tail_lens_l: MeshInstance3D = get_node_or_null("Lights/TailLensL")
@onready var tail_lens_r: MeshInstance3D = get_node_or_null("Lights/TailLensR")


func _ready() -> void:
	_update_car_mesh()
	_update_paint()
	_update_lights()


func _update_car_mesh() -> void:
	if cabin_sedan:
		cabin_sedan.visible = (body_style == BodyStyle.SEDAN or body_style == BodyStyle.HATCHBACK)
		if cabin_sedan.mesh is BoxMesh:
			var box = cabin_sedan.mesh as BoxMesh
			box.size = Vector3(1.6, 0.7, 2.2 if body_style == BodyStyle.SEDAN else 2.5)
	
	if cabin_wagon:
		cabin_wagon.visible = (body_style == BodyStyle.STATION_WAGON)
	
	if cabin_pickup:
		cabin_pickup.visible = (body_style == BodyStyle.PICKUP)
	
	if pickup_bed:
		pickup_bed.visible = (body_style == BodyStyle.PICKUP)


func _update_paint() -> void:
	var mat = StandardMaterial3D.new()
	mat.metallic = 0.5
	mat.roughness = 0.4
	
	match paint_color:
		PaintColor.CRIMSON_RED:
			mat.albedo_color = Color(0.65, 0.12, 0.12)
		PaintColor.NAVY_BLUE:
			mat.albedo_color = Color(0.12, 0.20, 0.45)
		PaintColor.CHARCOAL_BLACK:
			mat.albedo_color = Color(0.12, 0.12, 0.14)
		PaintColor.SILVER_GRAY:
			mat.albedo_color = Color(0.70, 0.72, 0.75)
		PaintColor.FOREST_GREEN:
			mat.albedo_color = Color(0.12, 0.28, 0.18)
		PaintColor.VINTAGE_WHITE:
			mat.albedo_color = Color(0.85, 0.84, 0.80)
	
	if lower_body:
		lower_body.material_override = mat
	if cabin_sedan:
		cabin_sedan.material_override = mat
	if cabin_wagon:
		cabin_wagon.material_override = mat
	if cabin_pickup:
		cabin_pickup.material_override = mat


func _update_lights() -> void:
	if headlight_l:
		headlight_l.visible = headlights_on
	if headlight_r:
		headlight_r.visible = headlights_on
	
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(1.0, 0.95, 0.85) if headlights_on else Color(0.3, 0.3, 0.3)
	head_mat.emission_enabled = headlights_on
	head_mat.emission = Color(1.0, 0.95, 0.8)
	head_mat.emission_energy_multiplier = 3.0 if headlights_on else 0.0
	
	if head_lens_l:
		head_lens_l.material_override = head_mat
	if head_lens_r:
		head_lens_r.material_override = head_mat
	
	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.8, 0.1, 0.1) if taillights_on else Color(0.3, 0.05, 0.05)
	tail_mat.emission_enabled = taillights_on
	tail_mat.emission = Color(1.0, 0.15, 0.15)
	tail_mat.emission_energy_multiplier = 2.0 if taillights_on else 0.0
	
	if tail_lens_l:
		tail_lens_l.material_override = tail_mat
	if tail_lens_r:
		tail_lens_r.material_override = tail_mat
