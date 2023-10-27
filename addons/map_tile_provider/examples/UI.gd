extends MarginContainer


func _ready():
	$VBoxContainer/PanelContainer/CenterContainer/TileDisplay._update_tile(
			int($VBoxContainer/HBoxContainer/Zoom.value)
	)
