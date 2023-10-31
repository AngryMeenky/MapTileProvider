extends Label


func _on_mosaic_zoom_changed(zoom: float):
	text = "Zoom: %f" % zoom
