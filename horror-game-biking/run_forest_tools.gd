@tool
extends EditorScript

func _run() -> void:
	var root = EditorInterface.get_edited_scene_root()
	var manager = root.get_node("ForestManager")
	#manager.remove_trees_outside_bounds()
	#manager.reposition_trees_around_path()
	#manager.densify_forest()
	#manager.randomize_tree_scale()
	#manager.optimize_forest_performance()
	manager.rebuild_all()
