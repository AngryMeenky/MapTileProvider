@tool
class_name MapTileLoader
extends Node


signal tile_loaded(status, tile: MapTile)


enum Provider {
	 BING,
	 MAPBOX,
	 MAPQUEST,
}


static var MAGIC := [
	PackedByteArray([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]),
	PackedByteArray([0xff, 0xd8, 0xff, 0x00]),
]

static var FORMATS := [
	 MapTile.Format.PNG,
	 MapTile.Format.JPG,
]


@export var custom_fields := {}
@export var user_agent := "Mozilla/5.0 Gecko/20100101 Firefox/118.0"
@export var allow_network := true
@export var cache_tiles := false
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

		if _map_provider:
			_map_provider.queue_free()
		_map_provider = new_provider
		apply_custom_fields()

		tile_provider = type
@export_range(1, 16) var concurrent_requests: int = 1:
	set(val):
		concurrent_requests = val
		while val > (_active.size() + _reserve.size()):
			var req = HTTPRequest.new()
			_reserve.append(req)
			add_child(req)

var _map_provider := MapProvider.new()
var _outstanding_requests := 0
var _active := []
var _reserve := []
var _local := []
var _waiting := []


func _ready():
	# force the creation of the correct map provider
	tile_provider = tile_provider
	# force the creation of the correct number of HTTPRequests
	concurrent_requests = concurrent_requests


func _process(delta):
	var idx: int = 0
	while idx < len(_local):
		var cache_path = _local[idx][0][1]
		match(ResourceLoader.load_threaded_get_status(cache_path)):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				idx += 1 # still loading
			ResourceLoader.THREAD_LOAD_LOADED:
				tile_loaded.emit(OK, ResourceLoader.load_threaded_get(cache_path))
				_local.remove_at(idx)
				_check_queued_loads()
			_:
				var result =_load_tile_from_server(_local[idx][0], _local[idx][1], true)
				if result != OK:
					tile_loaded.emit(result, null)
				_local.remove_at(idx)


func _check_queued_loads() -> void:
	var queued = _waiting.pop_front()
	if queued:
		_load_tile_from_server(queued[0], queued[1], false)


func apply_custom_fields() -> void:
	for key in custom_fields.keys():
		if key in _map_provider:
			_map_provider[key] = custom_fields[key]


func inflight() -> int:
	return _outstanding_requests


func available() -> int:
	var count = concurrent_requests - _outstanding_requests
	if count < 0:
		count = 0
	return count


func gps_to_tile(lat: float, lon: float, zoom: int) -> Vector3i:
	return Vector3i(
			_map_provider.longitude_to_tile(lon, zoom),
			_map_provider.latitude_to_tile(lat, zoom),
			zoom
	)


func get_tile_bounds(x: int, y: int, zoom: int) -> Rect2:
	return _map_provider.tile_to_bounds(x, y, zoom)


func _validate_image_format(data: PackedByteArray, expected: MapTile.Format):
	for idx in len(MAGIC):
		var found: bool = true
		for off in len(MAGIC[idx]):
			found = found and data[off] == MAGIC[idx][off]
		if found:
			return FORMATS[idx]

	return expected


func _handle_http_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, data: Array):
	data[0].request_completed.disconnect(data[1])
	_reserve.push_back(data[0])
	_outstanding_requests -= 1
	
	if result == HTTPRequest.RESULT_SUCCESS:
		if response_code == 200:
			var args = data[2]
			var tile = MapTile.new()
			tile.bounds = _map_provider.tile_to_bounds(args.x, args.y, args.zoom)
			tile.coords = Vector3i(args.x, args.y, args.zoom)
			tile.format = _validate_image_format(body, args.format)
			tile.image  = body
			if cache_tiles:
				ResourceSaver.save(tile, data[3][1])
			tile_loaded.emit(OK, tile)
		else:
			tile_loaded.emit(ERR_CANT_ACQUIRE_RESOURCE, null)
	else:
		tile_loaded.emit(ERR_CANT_CONNECT, null)
	_check_queued_loads()


func load_tile(lat: float, lon: float, zoom: int, queue: bool = false) -> Error:
	if available() <= 0 and not queue:
		return ERR_UNAVAILABLE

	# keep the values in the valid domain
	lat = clampf(lat, -90.0, 90.0)
	lon = clampf(lon, -180.0, 180.0)

	# create the URL and cache path of the desired tile
	var args = _map_provider._create_tile_parameters(lat, lon, zoom)
	var locs = [ _map_provider._construct_url(args), null ]
	locs[1] = _map_provider._url_to_cache(locs[0], args)
	# check the cache first
	if cache_tiles and FileAccess.file_exists(locs[1]):
		if ResourceLoader.load_threaded_request(locs[1], "MapTile") == OK:
			_local.append([ locs, args ])
			return OK

	# fallback to a tile server
	return _load_tile_from_server(locs, args, queue)


func _load_tile_from_server(locs: Array, args: Dictionary, queue: bool) -> Error:
	if not allow_network:
		return ERR_UNAVAILABLE

	var req: HTTPRequest = _reserve.pop_back()
	if req:
		_outstanding_requests += 1
		var data = [ req, null, args, locs ]
		data[1] = self._handle_http_response.bind(data)

		var headers: PackedStringArray = ["Accept: */*", "User-Agent: %s" % user_agent]
		if "referrer" in _map_provider:
			headers.append("Referrer: %s" % _map_provider.referrer)
		req.request_completed.connect(data[1])
		var err = req.request(locs[0], headers, HTTPClient.METHOD_GET)
		if err == OK:
			_active.push_back(req)
		else:
			req.request_completed.disconnect(data[1])
			_reserve.push_back(req)
			_outstanding_requests -= 1
		return err
	elif queue and _waiting.size() < 32:
		var found := false
		for request in _waiting:
			if request[0][1] == locs[0]:
				found = true
				break
		if not found:
			_waiting.push_back([ locs, args ])
			return OK

	# all parallel clients are currently being used
	return ERR_BUSY
