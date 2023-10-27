class_name MapTileResourceSaver
extends ResourceFormatSaver


func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	if is_instance_of(resource, MapTile):
		return PackedStringArray(["tile"])
	return PackedStringArray([])


func _recognize(resource: Resource) -> bool:
	return is_instance_of(resource, MapTile)


func _save(resource: Resource, path: String, flags: int) -> Error:
	var dir = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var tile: MapTile = resource
		tile.pack(file)
		file.close()
		return OK

	return ERR_CANT_OPEN
