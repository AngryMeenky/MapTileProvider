extends Label


func _ready():
	_on_zoom_value_changed($"../Zoom".value)


func _on_zoom_value_changed(value):
	self.text = "Zoom: %2d" % int(value)
