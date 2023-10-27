class_name MapTileResourceLoader
extends ResourceFormatLoader


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tile"])


func _handles_type(name: StringName) -> bool:
	return name == "MapTile"


func _get_resource_type(path: String) -> String:
	if path.ends_with(".tile"):
		return "MapTile"
	return ""


func _load(path: String, orig_path: String, sub_threads: bool, cache_mode: int) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var tile: MapTile = MapTile.new()
		var result = tile.unpack(file)
		file.close()
		if result != OK:
			return result
		return tile
		
	return ERR_CANT_OPEN
