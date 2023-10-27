@tool
class_name MapQuestMapProvider
extends MapProvider


@export var referrer := "https://mapquest.com"
@export var api_key := ""


func _construct_url(args: Dictionary) -> String:
	var url: String

	match self.map_style:
		MapType.SATELLITE:
			url = "https://1.aerial.maps.ls.hereapi.com/maptile/2.1/maptile/newest/satellite.day/{zoom}/{x}/{y}/256/jpg?apiKey={key}"
		#MapType.HYBRID:
		#	url = "http://otile{server}.mqcdn.com/tiles/1.0.0/sat/{zoom}/{x}/{y}.jpg"
		MapType.STREET:
			url = "https://vector.hereapi.com/v2/vectortiles/base/mc/{zoom}/{x}/{y}/omv?apikey={key}"
		_:
			url = "invalid://server {server}/quad {quad}/x {x}/y {y}/zoom {zoom}/lang {lang}"

	args["key"] = api_key
	args["format"] = MapTile.Format.JPG
	return url.format(args)


func _url_to_cache(url: String, args: Dictionary) -> String:
	args["md5"] = url.md5_text()
	return "user://tiles/mapquest/{zoom}/{md5}".format(args)
