@tool
class_name MapProvider
extends Node


enum MapType {
	 SATELLITE,
	 STREET,
	 HYBRID,
}


@export var language_code := "en"
@export var map_style := MapType.SATELLITE


func _create_tile_parameters_for_indices(x: int, y: int, zoom: int) -> Dictionary:
	return {
		"server": _select_server(x, y),
		"quad": _construct_quad_key(x, y, zoom),
		"x": x,
		"y": y,
		"zoom": zoom,
		"lang": language_code,
		"map_style": map_style,
		"format": MapTile.Format.BMP
	}


func _create_tile_parameters(lat: float, lon: float, zoom: int) -> Dictionary:
	return _create_tile_parameters_for_indices(
			longitude_to_tile(lon, zoom), latitude_to_tile(lat, zoom), zoom
	)


func get_tile_url(lat: float, lon: float, zoom: int) -> String:
	return _construct_url(_create_tile_parameters(lat, lon, zoom))


func get_tile_cache_path(lat: float, lon: float, zoom: int) -> String:
	var args = _create_tile_parameters(lat, lon, zoom)

	return _url_to_cache(_construct_url(args), args)


func get_tile_locations(lat: float, lon: float, zoom: int) -> Array:
	var args = _create_tile_parameters(lat, lon, zoom)	
	var url = _construct_url(args)

	return [ url, _url_to_cache(url, args) ]


static func longitude_to_tile(lon: float, zoom: int) -> int:
	return floori((lon + 180.0) / 360.0 * (1 << zoom))


static func latitude_to_tile(lat: float, zoom: int) -> int:
	return floori(
			(1.0 - log(tan(deg_to_rad(lat)) + 1.0 / cos(deg_to_rad(lat))) / PI) /
			2.0 * (1 << zoom)
	)


static func tile_to_longitude(x: int, zoom: int) -> float:
	return x * 360.0 / (1 << zoom) - 180.0


static func tile_to_latitude(y: int, zoom: int) -> float:
	return rad_to_deg(atan(sinh(PI * (1 - 2.0 * y / (1 << zoom)))))


static func tile_to_coordinates(x: int, y: int, zoom: int) -> Vector2:
	return Vector2(tile_to_latitude(y, zoom), tile_to_longitude(x, zoom))


static func tile_to_bounds(x: int, y: int, zoom: int) -> Rect2:
	var lat = tile_to_latitude(y, zoom)
	var lon = tile_to_longitude(x, zoom)

	return Rect2(
			lon, lat,
			tile_to_longitude(x + 1, zoom) - lon, tile_to_latitude(y - 1, zoom) - lat
	)


func _construct_url(args: Dictionary) -> String:
	return "debug://server{server}/q{quad}/x{x}/y{y}?zoom={zoom}&lang={lang}".format(args)


func _construct_quad_key(x: int, y: int, zoom: int) -> String:
	var str: PackedByteArray = []
	var i: int = zoom

	while i > 0:
		i -= 1
		var digit: int = 0x30
		var mask: int = 1 << i
		if (x & mask) != 0:
			digit += 1
		if (y & mask) != 0:
			digit += 2
		str.append(digit)

	return str.get_string_from_ascii()


func _select_server(x: int, y: int) -> int:
	return (x + 2 * y) % 4


func _url_to_cache(url: String, args: Dictionary) -> String:
	return "user://tiles/debug/%d/%s.tile" % [ args["zoom"], url.md5_text() ]
