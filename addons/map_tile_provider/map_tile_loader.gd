@tool
class_name MapTileLoader
extends Node


static var MAGIC: Array = [
	PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
	PackedByteArray([0xFF, 0xD8, 0xFF, 0x00])
]

static var FORMATS: Array = [ MapTile.Format.PNG, MapTile.Format.JPG ]


signal tile_loaded(status, tile: MapTile)


enum Provider { BING, MAPBOX, MAPQUEST }


@export var custom_fields: Dictionary = {}
@export var user_agent: String = "Mozilla/5.0 Gecko/20100101 Firefox/118.0"
@export var allow_network: bool = true
@export var cache_tiles: bool = false
@export var tile_provider: Provider:
	set(type):
		var new_provider: MapProvider
		match type:
			Provider.BING:
				new_provider = BingMapProvider.new()
			Provider.MAPBOX:
				new_provider = MapboxMapProvider.new()
			Provider.MAPQUEST:
				new_provider = MapQuestMapProvider.new()
			_:
				new_provider = MapProvider.new()

		if map_provider:
			map_provider.queue_free()
		map_provider = new_provider
		apply_custom_fields()

		tile_provider = type
@export_range(1, 16) var concurrent_requests: int = 1:
	set(val):
		concurrent_requests = val
		while val > (active.size() + reserve.size()):
			var req = HTTPRequest.new()
			reserve.append(req)
			add_child(req)

var map_provider: MapProvider = MapProvider.new()
var outstanding_requests: int = 0
var active: Array = []
var reserve: Array = []
var local: Array = []
var waiting: Array = []


func _ready():
	var i: int = active.size() + reserve.size()
	while i < concurrent_requests:
		i += 1
		var req = HTTPRequest.new()
		reserve.append(req)
		add_child(req)
	# force the creation of the correct map provider
	tile_provider = tile_provider


func _process(delta):
	var idx: int = 0
	while idx < len(local):
		match(ResourceLoader.load_threaded_get_status(local[idx][0][1])):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				idx += 1 # still loading
			ResourceLoader.THREAD_LOAD_LOADED:
				tile_loaded.emit(OK, ResourceLoader.load_threaded_get(local[idx][0][1]))
				local.remove_at(idx)
			_:
				var result =_load_tile_from_server(local[idx][0], local[idx][1], true)
				if result != OK:
					tile_loaded.emit(result, null)
				local.remove_at(idx)


func apply_custom_fields() -> void:
	for key in custom_fields.keys():
		if key in map_provider:
			map_provider[key] = custom_fields[key]


func inflight() -> int:
	return outstanding_requests


func available() -> int:
	var count = concurrent_requests - outstanding_requests
	if count < 0:
		count = 0
	return count


func _validate_image_format(data: PackedByteArray, expected: MapTile.Format):
	for idx in len(MAGIC):
		var found: bool = true
		for off in len(MAGIC[idx]):
			found = found && data[off] == MAGIC[idx][off]
		if found:
			return FORMATS[idx]

	return expected


func _handle_http_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, data: Array):
	data[0].request_completed.disconnect(data[1])
	reserve.push_back(data[0])
	outstanding_requests -= 1
	
	if result == HTTPRequest.RESULT_SUCCESS:
		if response_code == 200:
			var args = data[2]
			var tile = MapTile.new()
			tile.bounds = map_provider.tile_to_bounds(args.x, args.y, args.zoom)
			tile.coords = Vector3i(args.x, args.y, args.zoom)
			tile.format = _validate_image_format(body, args.format)
			tile.image  = body
			if cache_tiles:
				ResourceSaver.save(tile, data[3][1])
			tile_loaded.emit(OK, tile)
			if !waiting.is_empty():
				var queued = waiting.pop_front()
				if queued:
					_load_tile_from_server(queued[0], queued[1], true)
		else:
			tile_loaded.emit(ERR_CANT_ACQUIRE_RESOURCE, null)
	else:
		tile_loaded.emit(ERR_CANT_CONNECT, null)


func load_tile(lat: float, lon: float, zoom: int, queue: bool = false) -> Error:
	if available() <= 0:
		return ERR_UNAVAILABLE

	# keep the values in the valid domain
	lat = clampf(lat, -90.0, 90.0)
	lon = clampf(lon, -180.0, 180.0)

	# create the URL and cache path of the desired tile
	var args = map_provider._create_tile_parameters(lat, lon, zoom)
	var locs = [ map_provider._construct_url(args), null ]
	locs[1] = map_provider._url_to_cache(locs[0], args)
	# check the cache first
	if cache_tiles && FileAccess.file_exists(locs[1]):
		if ResourceLoader.load_threaded_request(locs[1], "MapTile") == OK:
			local.append([ locs, args ])
			return OK

	# fallback to a tile server
	return _load_tile_from_server(locs, args, queue)


func _load_tile_from_server(locs: Array, args: Dictionary, queue: bool) -> Error:
	if !allow_network:
		return ERR_UNAVAILABLE

	var req: HTTPRequest = reserve.pop_back()
	if req:
		outstanding_requests += 1
		var data = [ req, null, args, locs ]
		data[1] = self._handle_http_response.bind(data)

		var headers: PackedStringArray = ["Accept: */*", "User-Agent: %s" % user_agent]
		if "referrer" in map_provider:
			headers.append("Referrer: %s" % map_provider.referrer)
		req.request_completed.connect(data[1])
		var err = req.request(locs[0], headers, HTTPClient.METHOD_GET)
		if err == OK:
			active.push_back(req)
		else:
			req.request_completed.disconnect(data[1])
			reserve.push_back(req)
			outstanding_requests -= 1
		return err
	elif queue:
		waiting.push_back([ locs, args ])

	# all parallel clients are currently being used
	return ERR_BUSY
