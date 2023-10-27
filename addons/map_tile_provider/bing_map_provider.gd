@tool
class_name BingMapProvider
extends MapProvider

@export var referrer := "https://www.bing.com/maps/"
@export var api_version := "563"


func _construct_url(args: Dictionary) -> String:
	var url: String

	match self.map_style:
		MapType.SATELLITE:
			url = "http://ecn.t{server}.tiles.virtualearth.net/tiles/a{quad}.jpeg?g={api}&mkt={lang}"
			args["format"] = MapTile.Format.JPG
		MapType.STREET:
			url = "http://ecn.t{server}.tiles.virtualearth.net/tiles/r{quad}.png?g={api}&mkt={lang}"
			args["format"] = MapTile.Format.PNG
		MapType.HYBRID:
			url = "http://ecn.t{server}.tiles.virtualearth.net/tiles/h{quad}.jpeg?g={api}&mkt={lang}"
			args["format"] = MapTile.Format.JPG
		_:
			url = "invalid://server {server}/quad {quad}/x {x}/y {y}/zoom {zoom}/lang {lang}/api {api}"
			args["format"] = MapTile.Format.BMP

	args["api"] = api_version

	return url.format(args)


func _url_to_cache(url: String, args: Dictionary) -> String:
	args["md5"] = url.md5_text()
	return "user://tiles/bing/{zoom}/{md5}.tile".format(args)
