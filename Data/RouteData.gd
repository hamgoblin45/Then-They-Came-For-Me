extends Resource
class_name RouteData

@export var paths: Array[PathData]
var current_path: PathData

func _set_path():
	if not current_path and paths.size() > 0:
		current_path = paths[0]
		EventBus.path_updated.emit(current_path)
		print("RouteData.gd: Setting path to %s" % current_path)
		return
	for p in paths:
		if p and paths[-1] and p == paths[-1]:
			print("RouteData.gd: route finished")
			EventBus.route_finished.emit(self)
			return
		if p and p == current_path:
			var path_index = paths.find(p)
			var next_path: PathData = paths[path_index + 1]
			current_path = next_path
			EventBus.path_updated.emit(current_path)
			print("RouteData.gd: updating path to %s" % current_path)
			return
