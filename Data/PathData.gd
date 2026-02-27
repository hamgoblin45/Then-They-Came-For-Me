extends Resource
class_name PathData

@export var start_pos: Vector3
@export var points: Array[Vector3]
@export var wait_for_player: bool = false
@export var anim_on_arrival: String = ""

var _current_index: int = 0

func reset_path():
	_current_index = 0

func get_next_target() -> bool:
	return not points.is_empty()

func get_current_target() -> Vector3:
	if _current_index < points.size():
		return points[_current_index]
	return Vector3.ZERO

func advance_to_next() -> bool:
	_current_index += 1
	return _current_index < points.size()
