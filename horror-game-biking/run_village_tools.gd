@tool
extends EditorScript

func _run() -> void:
	var selection = EditorInterface.get_selection().get_selected_nodes()
	var root = EditorInterface.get_edited_scene_root()
	
	var count := 0
	if selection.is_empty():
		# Wenn nichts ausgewählt ist, alle Häuser in der Szene randomisieren
		count = randomize_all_in_node(root)
		print("Village Tools: Alle %d Häuser in der Szene zufällig variiert." % count)
	else:
		# Ausgewählte Häuser / Ordner randomisieren
		for node in selection:
			count += randomize_all_in_node(node)
		print("Village Tools: %d ausgewählte Häuser zufällig variiert." % count)


func randomize_all_in_node(parent: Node) -> int:
	var count := 0
	if parent.has_method("randomize_house"):
		parent.call("randomize_house")
		count += 1
	
	for child in parent.get_children():
		count += randomize_all_in_node(child)
	
	return count
