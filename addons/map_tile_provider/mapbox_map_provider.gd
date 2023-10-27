@tool
class_name MapboxMapProvider
extends MapProvider


@export var referrer := "https://www.mapbox.com/"
@export var account := ""
@export var token := ""
@export var custom_style := ""


func _construct_url(args: Dictionary) -> String:
	var url: String

	match args.map_style:
		MapType.SATELLITE:
			args["style"] = "satellite-v9"
		MapType.STREET:
			args["style"] = "streets-v10"
		MapType.HYBRID:
			args["style"] = "satellite-streets-v10"
		_:
			args["style"] = "UNKNOWN"

	if token == "":
		url = "invalid://server {server}/quad {quad}/x {x}/y {y}/zoom {zoom}/lang {lang}/account {account}/token {token}/style {style}"
		args["format"] = MapTile.Format.BMP
	elif custom_style == "":
		args["format"] = MapTile.Format.JPG
		url = "https://api.mapbox.com/styles/v1/mapbox/{style}/tiles/{zoom}/{x}/{y}?access_token={token}"
	else:
		args["style"] = custom_style
		args["format"] = MapTile.Format.JPG
		url = "https://api.mapbox.com/styles/v1/{account}/{style}/tiles/256/{zoom}/{x}/{y}?access_token={token}"

	return url.format(args)


func _url_to_cache(url: String, args: Dictionary) -> String:
	args["md5"] = url.md5_text()
	return "user://tiles/mapbox/{zoom}/{md5}.tile".format(args)
