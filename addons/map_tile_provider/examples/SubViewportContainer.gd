extends SubViewportContainer


@onready var _map = $SubViewport/Map


# Called when the node enters the scene tree for the first time.
func _ready():
	_on_resized()
	_map.recenter()

func _on_resized():
	$SubViewport.size = self.size


func _input(event):
	if event is InputEventMouseMotion and event.button_mask == 1:
		_map.shift(event.relative)
	elif event is InputEventMouseButton:
		if event.button_mask == 8:
			_map.zoom += 1
		elif event.button_mask == 16:
			_map.zoom -= 1
