extends PanelContainer

@onready var day_label: Label = $VBoxContainer/DayLabel
@onready var time_label: Label = $VBoxContainer/TimeLabel


func _ready() -> void:
	EventBus.minute_changed.connect(_on_minute_changed)
	day_label.text = GameState.weekday

func _on_minute_changed(hour: int, minute: int):
	var min_string: String = str(minute)
	if minute < 10:
		min_string = "0" + str(minute)
	time_label.text = str(hour) + ":" + str(min_string)
