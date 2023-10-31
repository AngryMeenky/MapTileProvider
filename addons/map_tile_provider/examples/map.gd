extends Node2D


signal zoom_changed(float)
signal latitude_changed(float)
signal longitude_changed(float)


@export var latitude: float = 0.0:
	set(val):
		latitude = val
		latitude_changed.emit(val)
		_update_visible_rect()

@export var longitude: float = 0.0:
	set(val):
		longitude = val
		longitude_changed.emit(val)
		_update_visible_rect()

@export_range(1, 20) var zoom: float = 1:
	set(val):
		if val >= 1.0 and val < 21.0:
			if int(zoom) != int(val):
				var maximum = int(val)
				var minimum = maximum - 1
				for idx in _zooms.size():
					var level = _zooms[idx]
					var layer = level["layer"]
					if layer == null:
						continue
					layer.visible = idx >= minimum and idx <= maximum
				call_deferred("_update_visible_rect")

			zoom = val
			zoom_changed.emit(val)


# canvas size
var _size := Vector2i()
# display layers
@onready var _zooms: Array[Dictionary] = [
	{ "layer": null    }, { "layer": $Zoom1  }, { "layer": $Zoom2  },
	{ "layer": $Zoom3  }, { "layer": $Zoom4  }, { "layer": $Zoom5  },
	{ "layer": $Zoom6  }, { "layer": $Zoom7  }, { "layer": $Zoom8  },
	{ "layer": $Zoom9  }, { "layer": $Zoom10 }, { "layer": $Zoom11 },
	{ "layer": $Zoom12 }, { "layer": $Zoom13 }, { "layer": $Zoom14 },
	{ "layer": $Zoom15 }, { "layer": $Zoom16 }, { "layer": $Zoom17 },
	{ "layer": $Zoom18 }, { "layer": $Zoom19 }, { "layer": $Zoom20 },
]


# Called when the node enters the scene tree for the first time.
func _ready():
	print("_ready")
	_update_visible_rect()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func recenter():
	var loader = $MapTileLoader
	var sprite: Sprite2D
	var level: Dictionary
	var layer: Node2D
	var step: Vector2
	var bounds: Rect2
	var coords: Vector3i

	for idx in _zooms.size():
		level = _zooms[idx]
		layer = level["layer"]
		if layer == null or not layer.visible:
			continue # skip this zoom level without backing

		sprite = null
		for key in level.keys():
			if key != "layer":
				sprite = level[key]["sprite"]
				break
		if sprite == null:
			continue # skip zoom levels without sprites

		coords = loader.gps_to_tile(latitude, longitude, idx)
		bounds = loader.get_tile_bounds(coords.x, coords.y, idx)
		step = sprite.texture.get_size()
		
		layer.position = Vector2(
				(coords.x + (longitude - bounds.position.x) / bounds.size.x) * -step.x,
				(coords.y - (latitude - bounds.position.y) / bounds.size.y) * -step.y
		)


func _place_sprite(level: Dictionary, tile: Dictionary):
	var sprite: Sprite2D = tile["sprite"]
	var step := sprite.texture.get_size()
	var coords: Vector3i = tile["coords"]
	var layer = level["layer"]
	sprite.position = Vector2(step.x * coords.x, step.y * coords.y)
	layer.add_child(sprite)

	if layer.get_child_count() == 1:
		recenter()


func _update_visible_rect() -> void:
	if not is_node_ready():
		return

	var level = _zooms[int(zoom)]
	var layer = level["layer"]
	if layer == null:
		return

	var step := Vector2(256, 256)
	for key in level.keys():
		if key != "layer":
			step = level[key]["sprite"].texture.get_size()
			break

	var loader = $MapTileLoader
	var center_tile: Vector3i = loader.gps_to_tile(latitude, longitude, int(zoom))
	var tile_bounds: Rect2 = loader.get_tile_bounds(center_tile.x, center_tile.y, center_tile.z)
	var range_x = ((int(_size.x + step.x) - 1) / int(step.x) + 1) / 2 + 1
	var range_y = ((int(_size.y + step.y) - 1) / int(step.y) + 1) / 2 + 1
	var base_lon = tile_bounds.position.x + tile_bounds.size.x * 0.5
	var base_lat = tile_bounds.position.y + tile_bounds.size.y * 0.5
	for x in range(-range_x, range_x):
		for y in range(-range_y, range_y):
			var key = "%d,%d" % [ x, y ]
			if level.has(key):
				continue
			loader.load_tile(
				base_lat + y * tile_bounds.size.y, 
				base_lon + x * tile_bounds.size.x,
				center_tile.z,
				true
			)
	recenter()


func _on_sub_viewport_size_changed():
	_size = $"..".size
	call_deferred("_update_visible_rect")


func _on_tile_loaded(status, tile):
	if status == OK:
		var zoom_level := _zooms[tile.coords.z]
		var key := "%d,%d" % [ tile.coords.x, tile.coords.y ]
		if zoom_level.has(key):
			return # ignore duplicate

		var img = Image.new()
		status = tile.to_image(img)
		if status == OK:
			var sprite = Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(img)
			zoom_level[key] = {
				"sprite": sprite,
				"coords": tile.coords,
				"bounds": tile.bounds,
			}
			_place_sprite(zoom_level, zoom_level[key])


func _on_zoom_changed(z: float):
	if zoom >= 1.0 and zoom < 21.0:
		if int(zoom) != int(z):
			var maximum = int(z)
			var minimum = maximum - 1
			for idx in _zooms.size():
				var level = _zooms[idx]
				var layer = level["layer"]
				if layer == null:
					continue
				layer.visible = idx >= minimum and idx <= maximum
		zoom = z
		call_deferred("_update_visible_rect")


func shift(amount: Vector2) -> void:
	var level = _zooms[int(zoom)]
	var layer = level["layer"]
	if layer == null:
		return # skip layer 0

	var deg_per_pix: Vector2
	# get current center tile
	var loader = $MapTileLoader
	var center_tile = loader.gps_to_tile(latitude, longitude, int(zoom))
	# determine the degrees per pixel
	var key = "%d,%d" % [ center_tile.x, center_tile.y ]
	if key in layer:
		var tile = layer[key]
		var degrees = tile["bounds"].size
		var step = tile["sprite"].texture.get_size()
		deg_per_pix = Vector2(degrees.x / step.x, degrees.y / step.y)
	else:
		var degrees = loader.get_tile_bounds(center_tile.x, center_tile.y, center_tile.z).size
		deg_per_pix = Vector2(degrees.x / 256.0, degrees.y / 256.0)

	# update the current coordinates
	longitude -= amount.x * deg_per_pix.x
	latitude += amount.y * deg_per_pix.y
	call_deferred("_update_visible_rect")
