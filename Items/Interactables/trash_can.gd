extends Area3D
class_name TrashCan

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if body is GuestClue:
		print("TrashCan: Player successfully disposed of a clue!")
		
		# Optional: Play a crumpling sound or poof particle effect here
		
		body.remove_from_group("clues")
		body.queue_free()
