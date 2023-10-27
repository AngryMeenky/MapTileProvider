@tool
class_name MapTile
extends Resource

enum Format { BMP, JPG, PNG, TGA, WEBP }

@export var bounds: Rect2
@export var coords: Vector3i
@export var image: PackedByteArray
@export var format: Format


func _init(b: Rect2 = Rect2(), c: Vector3i = Vector3i.ZERO, i: PackedByteArray = [], f: Format = Format.JPG):
	bounds = b
	coords = c
	image = i
	format = f


func pack(file: FileAccess):
	file.store_var(bounds, true)
	file.store_var(coords, true)
	file.store_32(format)
	file.store_32(len(image))
	file.store_buffer(image)


func unpack(file: FileAccess) -> Error:
	if file.eof_reached(): return ERR_FILE_EOF
	bounds = file.get_var(true)
	if file.eof_reached(): return ERR_FILE_EOF
	coords = file.get_var(true)
	if file.eof_reached(): return ERR_FILE_EOF
	format = file.get_32()
	if file.eof_reached(): return ERR_FILE_EOF
	var expected = file.get_32()
	if file.eof_reached(): return ERR_FILE_EOF
	image = file.get_buffer(expected)
	if len(image) != expected: return ERR_FILE_EOF
	return OK


func to_image(img: Image) -> Error:
	match format:
		Format.BMP:
			return img.load_bmp_from_buffer(image)
		Format.JPG:
			return img.load_jpg_from_buffer(image)
		Format.PNG:
			return img.load_png_from_buffer(image)
		Format.TGA:
			return img.load_tga_from_buffer(image)
		Format.WEBP:
			return img.load_webp_from_buffer(image)
		_:
			return ERR_INVALID_DATA
