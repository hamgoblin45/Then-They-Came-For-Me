extends Label3D

func setup(text_content: String, color: Color = Color.WHITE):
	text = text_content
	modulate = color
	
	#Animate - float up and fade out (this can be tweaked later)
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "position:y", position.y + 0.5, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(queue_free)
