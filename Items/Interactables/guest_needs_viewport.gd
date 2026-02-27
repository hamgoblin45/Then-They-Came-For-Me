extends SubViewport

@onready var name_label = $VBoxContainer/GuestName
@onready var satiety_bar = $VBoxContainer/SatietyBar
@onready var stress_bar = $VBoxContainer/StressBar

# Colors for visual feedback
var color_good = Color.GREEN
var color_caution = Color.YELLOW
var color_danger = Color.RED

func update_needs(guest_name: String, satiety: float, stress: float):
	name_label.text = guest_name
	
	# Update Values
	satiety_bar.value = satiety
	stress_bar.value = stress
	
	# --- Satiety Coloring (Danger when Low) ---
	if satiety > 60:
		satiety_bar.modulate = color_good
	elif satiety > 25:
		satiety_bar.modulate = color_caution
	else:
		satiety_bar.modulate = color_danger
		
	# --- Stress Coloring (Danger when High) ---
	if stress < 40:
		stress_bar.modulate = color_good
	elif stress < 75:
		stress_bar.modulate = color_caution
	else:
		stress_bar.modulate = color_danger
