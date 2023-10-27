extends TextureRect


var tex: ImageTexture
var update: bool = false


func _ready():
	tex = texture
	tex.set_image(Image.create(256, 256,true, Image.FORMAT_RGB8))


func _on_tile_loaded(status, tile):
	if status == OK:
		var img = Image.new()
		if tile.to_image(img) == OK:
			tex.set_image(img)


func _update_tile(zoom: int):
	var err = $"/root/main/MapTileLoader".load_tile(
		float($"../../../HBoxContainer/Latitude".text),
		float($"../../../HBoxContainer/Longitude".text),
		zoom
	)


func _on_button_pressed():
	_update_tile(int($"../../../HBoxContainer/Zoom".value))


func _on_button_toggled(button_pressed):
	update = button_pressed
	if update:
		_update_tile(int($"../../../HBoxContainer/Zoom".value))


func _on_zoom_value_changed(value):
	if update:
		_update_tile(int(value))
