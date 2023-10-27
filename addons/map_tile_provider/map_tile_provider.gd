@tool
extends EditorPlugin


const MapTileResourceLoader = preload("res://addons/map_tile_provider/map_tile_resource_loader.gd")
const MapTileResourceSaver = preload("res://addons/map_tile_provider/map_tile_resource_saver.gd")


var _loader: MapTileResourceLoader
var _saver: MapTileResourceSaver


func _enter_tree():
	# initialize tile providers
	add_custom_type(
			"MapProvider", "Node",
			preload("res://addons/map_tile_provider/map_provider.gd"),
			preload("res://addons/map_tile_provider/map.svg")
	)
	add_custom_type(
			"BingMapProvider", "Node", 
			preload("res://addons/map_tile_provider/bing_map_provider.gd"),
			preload("res://addons/map_tile_provider/map.svg")
	)
	add_custom_type(
			"MapboxMapProvider", "Node",
			preload("res://addons/map_tile_provider/mapbox_map_provider.gd"),
			preload("res://addons/map_tile_provider/map.svg")
	)
	add_custom_type(
			"MapQuestMapProvider", "Node",
			preload("res://addons/map_tile_provider/mapquest_map_provider.gd"),
			preload("res://addons/map_tile_provider/map.svg")
	)
	# initialize the loader
	add_custom_type(
			"MapTile", "Resource",
			preload("res://addons/map_tile_provider/map_tile.gd"),
			preload("res://addons/map_tile_provider/tile.svg")
	)
	add_custom_type(
			"MapTileLoader", "Node",
			preload("res://addons/map_tile_provider/map_tile_loader.gd"),
			preload("res://addons/map_tile_provider/loader.svg")
	)
	_loader = MapTileResourceLoader.new()
	ResourceLoader.add_resource_format_loader(_loader)
	# initialize the saver
	_saver = MapTileResourceSaver.new()
	ResourceSaver.add_resource_format_saver(_saver)


func _exit_tree():
	# clean up the saver
	ResourceSaver.remove_resource_format_saver(_saver)
	# clean up the loader
	ResourceLoader.remove_resource_format_loader(_loader)
	remove_custom_type("MapTileLoader")
	remove_custom_type("MapTile")
	# clean up tile providers
	remove_custom_type("MapQuestMapProvider")
	remove_custom_type("MapboxMapProvider")
	remove_custom_type("BingMapProvider")
	remove_custom_type("MapProvider")
