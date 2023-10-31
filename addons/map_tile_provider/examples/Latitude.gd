extends Label


func _on_mosaic_latitude_changed(latitude: float):
	text = "Latitude: %f" % latitude
