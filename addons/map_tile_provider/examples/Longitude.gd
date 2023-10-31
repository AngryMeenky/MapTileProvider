extends Label


func _on_mosaic_longitude_changed(longitude: float):
	text = "Longitude: %f" % longitude
